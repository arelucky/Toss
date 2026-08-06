import AuthenticationServices
import UIKit

@MainActor
final class NativeAppleSignInService: AppleSignInServicing {
    private let nonceGenerator: NonceGenerator
    private let presentationAnchor: () -> ASPresentationAnchor?
    private var coordinator: AppleAuthorizationCoordinator?

    init(
        nonceGenerator: NonceGenerator = NonceGenerator(),
        presentationAnchor: (() -> ASPresentationAnchor?)? = nil
    ) {
        self.nonceGenerator = nonceGenerator
        self.presentationAnchor = presentationAnchor ?? Self.activePresentationAnchor
    }

    func signIn() async throws -> AppleSignInCredential {
        guard coordinator == nil else { throw AppleSignInError.requestInProgress }
        guard let anchor = presentationAnchor() else { throw AppleSignInError.missingPresentationAnchor }

        let rawNonce = try nonceGenerator.generate()
        let requestConfiguration = AppleAuthorizationRequestConfiguration(rawNonce: rawNonce)
        let request = ASAuthorizationAppleIDProvider().createRequest()
        request.nonce = requestConfiguration.nonce
        request.requestedScopes = requestConfiguration.requestedScopes

        return try await withCheckedThrowingContinuation { continuation in
            let completionGate = AppleAuthorizationCompletionGate<AppleSignInCredential> { [weak self] result in
                Task { @MainActor in
                    self?.coordinator = nil
                    continuation.resume(with: result)
                }
            }
            let coordinator = AppleAuthorizationCoordinator(
                request: request,
                rawNonce: rawNonce,
                presentationAnchor: anchor,
                completionGate: completionGate
            )
            self.coordinator = coordinator
            coordinator.perform()
        }
    }

    private static func activePresentationAnchor() -> ASPresentationAnchor? {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first { $0.isKeyWindow }
    }
}

private final class AppleAuthorizationCoordinator: NSObject,
    ASAuthorizationControllerDelegate,
    ASAuthorizationControllerPresentationContextProviding {
    private let controller: ASAuthorizationController
    private let rawNonce: String
    private let anchor: ASPresentationAnchor
    private let completionGate: AppleAuthorizationCompletionGate<AppleSignInCredential>

    init(
        request: ASAuthorizationAppleIDRequest,
        rawNonce: String,
        presentationAnchor: ASPresentationAnchor,
        completionGate: AppleAuthorizationCompletionGate<AppleSignInCredential>
    ) {
        controller = ASAuthorizationController(authorizationRequests: [request])
        self.rawNonce = rawNonce
        anchor = presentationAnchor
        self.completionGate = completionGate
        super.init()
        controller.delegate = self
        controller.presentationContextProvider = self
    }

    func perform() {
        controller.performRequests()
    }

    func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithAuthorization authorization: ASAuthorization
    ) {
        guard let appleCredential = authorization.credential as? ASAuthorizationAppleIDCredential else {
            completionGate.resolve(.failure(AppleSignInError.invalidCredential))
            return
        }
        completionGate.resolve(
            Result {
                try AppleSignInCredentialMapper.map(
                    identityToken: appleCredential.identityToken,
                    authorizationCode: appleCredential.authorizationCode,
                    fullName: appleCredential.fullName,
                    rawNonce: rawNonce
                )
            }
        )
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        completionGate.resolve(.failure(AppleSignInError.map(error)))
    }

    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        anchor
    }
}
