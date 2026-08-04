import Foundation

enum ServerSessionRevocation: Equatable { case revoked, deferred }

protocol AccountAuthServicing {
    func restoredSession() async throws -> AccountSession
    func signInWithApple(identityToken: String, rawNonce: String) async throws -> AccountSession
    func signOut() async throws -> ServerSessionRevocation
}
