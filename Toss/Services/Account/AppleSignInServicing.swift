import AuthenticationServices
import Foundation

struct AppleSignInCredential: Equatable {
    let identityToken: String
    let authorizationCode: String
    let rawNonce: String
    let displayName: String?
}

enum AppleSignInError: Error, Equatable {
    case cancelled
    case requestInProgress
    case missingPresentationAnchor
    case missingIdentityToken
    case invalidIdentityToken
    case missingAuthorizationCode
    case invalidAuthorizationCode
    case invalidCredential
    case requestFailed

    static func map(_ error: Error) -> Self {
        let nsError = error as NSError
        if nsError.domain == ASAuthorizationError.errorDomain,
           nsError.code == ASAuthorizationError.canceled.rawValue {
            return .cancelled
        }
        return .requestFailed
    }
}

@MainActor
protocol AppleSignInServicing {
    func signIn() async throws -> AppleSignInCredential
}

struct AppleAuthorizationRequestConfiguration: Equatable {
    let nonce: String
    let requestedScopes: [ASAuthorization.Scope]

    init(rawNonce: String) {
        nonce = NonceGenerator.sha256(rawNonce)
        requestedScopes = [.fullName]
    }
}

enum AppleSignInCredentialMapper {
    static func map(
        identityToken: Data?,
        authorizationCode: Data?,
        fullName: PersonNameComponents?,
        rawNonce: String
    ) throws -> AppleSignInCredential {
        guard let identityToken else { throw AppleSignInError.missingIdentityToken }
        guard let identityTokenValue = String(data: identityToken, encoding: .utf8),
              !identityTokenValue.isEmpty else {
            throw AppleSignInError.invalidIdentityToken
        }
        guard let authorizationCode else { throw AppleSignInError.missingAuthorizationCode }
        guard let authorizationCodeValue = String(data: authorizationCode, encoding: .utf8),
              !authorizationCodeValue.isEmpty else {
            throw AppleSignInError.invalidAuthorizationCode
        }

        return AppleSignInCredential(
            identityToken: identityTokenValue,
            authorizationCode: authorizationCodeValue,
            rawNonce: rawNonce,
            displayName: normalizedDisplayName(from: fullName)
        )
    }

    private static func normalizedDisplayName(from components: PersonNameComponents?) -> String? {
        guard let components else { return nil }
        let pieces = [components.givenName, components.middleName, components.familyName]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        guard !pieces.isEmpty else { return nil }
        return pieces.joined(separator: " ")
    }
}

final class AppleAuthorizationCompletionGate<Value> {
    private let lock = NSLock()
    private var completion: ((Result<Value, Error>) -> Void)?

    init(completion: @escaping (Result<Value, Error>) -> Void) {
        self.completion = completion
    }

    func resolve(_ result: Result<Value, Error>) {
        lock.lock()
        let completion = completion
        self.completion = nil
        lock.unlock()
        completion?(result)
    }
}
