import Foundation
import Supabase

struct AccountDeletionServerResponse: Equatable {
    let requestID: UUID
    let result: AccountDeletionResult
}

protocol AccountDeletionBackend: AnyObject {
    var currentGenerationID: SupabaseClientGenerationID { get }
    func isCurrent(_ generationID: SupabaseClientGenerationID) -> Bool
    func invoke(authorizationCode: String, requestID: UUID, generationID: SupabaseClientGenerationID) async throws -> AccountDeletionServerResponse
    func clearLocalSession(generationID: SupabaseClientGenerationID) throws
}

final class SupabaseAccountDeletionService: AccountDeletionServicing, ClientEnvironmentBacked {
    let environment: AppEnvironment?
    private let backend: any AccountDeletionBackend

    init(environment: AppEnvironment) {
        self.environment = environment
        backend = LiveAccountDeletionBackend(environment: environment)
    }

    init(backend: any AccountDeletionBackend) {
        environment = nil
        self.backend = backend
    }

    func deleteAccount(authorizationCode: String, requestID: UUID) async throws -> AccountDeletionResult {
        let generationID = backend.currentGenerationID
        guard backend.isCurrent(generationID) else { throw AccountDeletionServiceError.staleGeneration }
        let response = try await backend.invoke(
            authorizationCode: authorizationCode,
            requestID: requestID,
            generationID: generationID
        )
        guard backend.isCurrent(generationID) else { throw AccountDeletionServiceError.staleGeneration }
        guard response.requestID == requestID, response.result.deleted else {
            throw AccountDeletionServiceError.invalidResponse
        }
        do {
            try backend.clearLocalSession(generationID: generationID)
        } catch {
            throw AccountDeletionServiceError.localSessionCleanupFailed
        }
        return response.result
    }
}

private final class LiveAccountDeletionBackend: AccountDeletionBackend {
    private let environment: AppEnvironment

    init(environment: AppEnvironment) {
        self.environment = environment
    }

    var currentGenerationID: SupabaseClientGenerationID {
        environment.generationProvider.current().id
    }

    func isCurrent(_ generationID: SupabaseClientGenerationID) -> Bool {
        environment.generationProvider.isCurrent(generationID)
    }

    func invoke(
        authorizationCode: String,
        requestID: UUID,
        generationID: SupabaseClientGenerationID
    ) async throws -> AccountDeletionServerResponse {
        let generation = environment.generationProvider.current()
        guard generation.id == generationID, environment.generationProvider.isCurrent(generationID) else {
            throw AccountDeletionServiceError.staleGeneration
        }
        let response: DeleteAccountResponse = try await generation.client.functions.invoke(
            "delete-account",
            options: FunctionInvokeOptions(
                method: .post,
                body: DeleteAccountRequest(requestID: requestID, authorizationCode: authorizationCode)
            )
        )
        return AccountDeletionServerResponse(
            requestID: response.requestID,
            result: AccountDeletionResult(deleted: response.deleted, appleRevocation: response.appleRevocation)
        )
    }

    func clearLocalSession(generationID: SupabaseClientGenerationID) throws {
        let provider = environment.generationProvider
        let generation = try provider.beginRetirement(expectedID: generationID)
        if try environment.authStorage.retrieve(key: AppEnvironment.authStorageKey) != nil {
            try generation.authStorage.remove(key: AppEnvironment.authStorageKey)
        }
        try environment.authStorage.confirmSessionAbsent(key: AppEnvironment.authStorageKey)
        _ = try provider.finishRetirementAndActivateReplacement(expectedID: generationID)
    }
}

private struct DeleteAccountRequest: Encodable {
    let requestID: UUID
    let authorizationCode: String
}

private struct DeleteAccountResponse: Decodable {
    let deleted: Bool
    let requestID: UUID
    let appleRevocation: AppleRevocationStatus
}

extension AppleRevocationStatus: Codable {}
