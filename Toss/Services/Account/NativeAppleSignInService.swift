import AuthenticationServices
import UIKit

protocol AppleAuthorizationPerforming: AnyObject {
    func perform()
    func cancel()
}

typealias AppleAuthorizationCoordinatorFactory = (
    _ request: ASAuthorizationAppleIDRequest,
    _ rawNonce: String,
    _ presentationAnchor: ASPresentationAnchor,
    _ completionGate: AppleAuthorizationCompletionGate<AppleSignInCredential>
) -> any AppleAuthorizationPerforming

@MainActor
final class NativeAppleSignInService: AppleSignInServicing {
    private struct ActiveRequest {
        let id: UUID
        let coordinator: any AppleAuthorizationPerforming
        let completionGate: AppleAuthorizationCompletionGate<AppleSignInCredential>
    }

    private let nonceGenerator: NonceGenerator
    private let presentationAnchor: () -> ASPresentationAnchor?
    private let coordinatorFactory: AppleAuthorizationCoordinatorFactory
    private var activeRequest: ActiveRequest?

    init(
        nonceGenerator: NonceGenerator = NonceGenerator(),
        presentationAnchor: (() -> ASPresentationAnchor?)? = nil,
        coordinatorFactory: AppleAuthorizationCoordinatorFactory? = nil
    ) {
        self.nonceGenerator = nonceGenerator
        self.presentationAnchor = presentationAnchor ?? Self.activePresentationAnchor
        self.coordinatorFactory = coordinatorFactory ?? { request, rawNonce, anchor, gate in
            AppleAuthorizationCoordinator(
                request: request,
                rawNonce: rawNonce,
                presentationAnchor: anchor,
                completionGate: gate
            )
        }
    }

    func signIn() async throws -> AppleSignInCredential {
        try Task.checkCancellation()
        if activeRequest?.completionGate.isResolved == true {
            activeRequest = nil
        }
        guard activeRequest == nil else { throw AppleSignInError.requestInProgress }
        guard let anchor = presentationAnchor() else { throw AppleSignInError.missingPresentationAnchor }
        let requestID = UUID()

        let rawNonce = try nonceGenerator.generate()
        let requestConfiguration = AppleAuthorizationRequestConfiguration(rawNonce: rawNonce)
        let request = ASAuthorizationAppleIDProvider().createRequest()
        request.nonce = requestConfiguration.nonce
        request.requestedScopes = requestConfiguration.requestedScopes

        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                let completionGate = AppleAuthorizationCompletionGate<AppleSignInCredential> { [weak self] result in
                    Task { @MainActor in
                        self?.clearRequest(matching: requestID)
                        continuation.resume(with: result)
                    }
                }
                let coordinator = coordinatorFactory(request, rawNonce, anchor, completionGate)
                self.activeRequest = ActiveRequest(
                    id: requestID,
                    coordinator: coordinator,
                    completionGate: completionGate
                )
                if Task.isCancelled {
                    coordinator.cancel()
                    self.clearRequest(matching: requestID)
                } else {
                    coordinator.perform()
                }
            }
        } onCancel: { [service = self] in
            Task { @MainActor in service.cancelRequest(matching: requestID) }
        }
    }

    private static func activePresentationAnchor() -> ASPresentationAnchor? {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first { $0.isKeyWindow }
    }

    private func cancelRequest(matching requestID: UUID) {
        guard activeRequest?.id == requestID else { return }
        let coordinator = activeRequest?.coordinator
        activeRequest = nil
        coordinator?.cancel()
    }

    private func clearRequest(matching requestID: UUID) {
        guard activeRequest?.id == requestID else { return }
        activeRequest = nil
    }
}

private final class AppleAuthorizationCoordinator: NSObject,
    AppleAuthorizationPerforming,
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

    func cancel() {
        controller.cancel()
        completionGate.resolve(.failure(CancellationError()))
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
