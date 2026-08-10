import Foundation

enum AppleRevocationStatus: String, Equatable { case revoked; case alreadyInvalid = "already_invalid"; case manualRequired = "manual_required" }
struct AccountDeletionResult: Equatable { let deleted: Bool; let appleRevocation: AppleRevocationStatus }

enum AccountDeletionServiceError: Error, Equatable {
    case invalidResponse
    case staleGeneration
    case localSessionCleanupFailed
}

protocol AccountDeletionServicing {
    func deleteAccount(authorizationCode: String, requestID: UUID) async throws -> AccountDeletionResult
}
