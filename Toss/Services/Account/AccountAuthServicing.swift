import Foundation

enum ServerSessionRevocation: Equatable { case revoked, deferred }

enum AccountAuthEventKind: Equatable {
    case initialSession
    case signedIn
    case signedOut
    case tokenRefreshed
    case userUpdated
}

struct AccountAuthEvent: Equatable {
    let generationID: SupabaseClientGenerationID
    let kind: AccountAuthEventKind
    let session: AccountSession?
}

struct GenerationAccountSession: Equatable {
    let generationID: SupabaseClientGenerationID
    let session: AccountSession
}

protocol AccountAuthServicing {
    var currentGenerationID: SupabaseClientGenerationID { get }
    func restoredSession() async throws -> GenerationAccountSession
    func signInWithApple(identityToken: String, rawNonce: String) async throws -> GenerationAccountSession
    func sessionChanges() -> AsyncStream<AccountAuthEvent>
    func signOut() async throws -> ServerSessionRevocation
    func isCurrentGeneration(_ generationID: SupabaseClientGenerationID) -> Bool
}

extension AccountAuthServicing {
    var currentGenerationID: SupabaseClientGenerationID { .legacy }

    func isCurrentGeneration(_ generationID: SupabaseClientGenerationID) -> Bool {
        generationID == currentGenerationID
    }
}
