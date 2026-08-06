import AuthenticationServices
import UIKit
import XCTest
@testable import Toss

final class NativeAppleSignInServiceTests: XCTestCase {
    func testRequestConfigurationHashesNonceAndRequestsOnlyFullName() {
        let configuration = AppleAuthorizationRequestConfiguration(rawNonce: "raw-nonce")

        XCTAssertEqual(configuration.nonce, NonceGenerator.sha256("raw-nonce"))
        XCTAssertEqual(configuration.requestedScopes, [.fullName])
        XCTAssertFalse(configuration.requestedScopes.contains(.email))
    }

    func testCredentialMapperReturnsTransientCredential() throws {
        var name = PersonNameComponents()
        name.givenName = " Ada "
        name.familyName = " Lovelace "

        let credential = try AppleSignInCredentialMapper.map(
            identityToken: Data("identity-token".utf8),
            authorizationCode: Data("authorization-code".utf8),
            fullName: name,
            rawNonce: "raw-nonce"
        )

        XCTAssertEqual(credential.identityToken, "identity-token")
        XCTAssertEqual(credential.authorizationCode, "authorization-code")
        XCTAssertEqual(credential.rawNonce, "raw-nonce")
        XCTAssertEqual(credential.displayName, "Ada Lovelace")
    }

    func testCredentialMapperRejectsMissingIdentityToken() {
        XCTAssertThrowsError(
            try AppleSignInCredentialMapper.map(
                identityToken: nil,
                authorizationCode: Data("authorization-code".utf8),
                fullName: nil,
                rawNonce: "raw-nonce"
            )
        ) { error in
            XCTAssertEqual(error as? AppleSignInError, .missingIdentityToken)
        }
    }

    func testCredentialMapperRejectsNonUTF8IdentityToken() {
        XCTAssertThrowsError(
            try AppleSignInCredentialMapper.map(
                identityToken: Data([0xFF]),
                authorizationCode: Data("authorization-code".utf8),
                fullName: nil,
                rawNonce: "raw-nonce"
            )
        ) { error in
            XCTAssertEqual(error as? AppleSignInError, .invalidIdentityToken)
        }
    }

    func testCredentialMapperRejectsMissingAuthorizationCode() {
        XCTAssertThrowsError(
            try AppleSignInCredentialMapper.map(
                identityToken: Data("identity-token".utf8),
                authorizationCode: nil,
                fullName: nil,
                rawNonce: "raw-nonce"
            )
        ) { error in
            XCTAssertEqual(error as? AppleSignInError, .missingAuthorizationCode)
        }
    }

    func testCredentialMapperRejectsNonUTF8AuthorizationCode() {
        XCTAssertThrowsError(
            try AppleSignInCredentialMapper.map(
                identityToken: Data("fictional-identity-token".utf8),
                authorizationCode: Data([0xFF]),
                fullName: nil,
                rawNonce: "fictional-raw-nonce"
            )
        ) { error in
            XCTAssertEqual(error as? AppleSignInError, .invalidAuthorizationCode)
        }
    }

    func testCredentialMapperOmitsWhitespaceOnlyName() throws {
        var name = PersonNameComponents()
        name.givenName = "  "

        let credential = try AppleSignInCredentialMapper.map(
            identityToken: Data("identity-token".utf8),
            authorizationCode: Data("authorization-code".utf8),
            fullName: name,
            rawNonce: "raw-nonce"
        )

        XCTAssertNil(credential.displayName)
    }

    func testCancellationMapsToNormalCancelledResult() {
        let error = NSError(
            domain: ASAuthorizationError.errorDomain,
            code: ASAuthorizationError.canceled.rawValue
        )

        XCTAssertEqual(AppleSignInError.map(error), .cancelled)
    }

    func testCompletionGateDeliversOnlyFirstCallback() {
        var received: [Result<Int, Error>] = []
        let gate = AppleAuthorizationCompletionGate<Int> { received.append($0) }

        gate.resolve(.success(1))
        gate.resolve(.success(2))

        XCTAssertEqual(try? received.first?.get(), 1)
        XCTAssertEqual(received.count, 1)
    }

    @MainActor
    func testCancellingInFlightRequestCancelsControllerAndAllowsNextRequest() async throws {
        let factory = AppleAuthorizationControllerFactoryDouble()
        let service = NativeAppleSignInService(
            presentationAnchor: { UIWindow() },
            coordinatorFactory: factory.make
        )
        let first = Task { try await service.signIn() }
        let firstController = await factory.nextController()

        first.cancel()
        do {
            _ = try await first.value
            XCTFail("Expected cancellation")
        } catch {
            XCTAssertTrue(error is CancellationError)
        }
        XCTAssertEqual(firstController.cancelCount, 1)

        firstController.succeed(with: .fixture())
        firstController.fail(with: AppleSignInError.requestFailed)

        let second = Task { try await service.signIn() }
        let secondController = await factory.nextController()
        secondController.succeed(with: .fixture())
        _ = try await second.value
        XCTAssertEqual(factory.createdCount, 2)
    }

    @MainActor
    func testCancellingRequestIgnoresLateFailureCallback() async {
        let factory = AppleAuthorizationControllerFactoryDouble()
        let service = NativeAppleSignInService(
            presentationAnchor: { UIWindow() },
            coordinatorFactory: factory.make
        )
        let task = Task { try await service.signIn() }
        let controller = await factory.nextController()

        task.cancel()
        _ = await task.result
        controller.fail(with: AppleSignInError.requestFailed)

        XCTAssertEqual(controller.cancelCount, 1)
        XCTAssertTrue(controller.didReceiveLateCallback)
    }
}

@MainActor
private final class AppleAuthorizationControllerFactoryDouble {
    private var available: [AppleAuthorizationControllerDouble] = []
    private var waiting: [CheckedContinuation<AppleAuthorizationControllerDouble, Never>] = []
    private(set) var createdCount = 0

    func make(
        request: ASAuthorizationAppleIDRequest,
        rawNonce: String,
        presentationAnchor: ASPresentationAnchor,
        completionGate: AppleAuthorizationCompletionGate<AppleSignInCredential>
    ) -> any AppleAuthorizationPerforming {
        let controller = AppleAuthorizationControllerDouble(completionGate: completionGate)
        createdCount += 1
        if !waiting.isEmpty {
            waiting.removeFirst().resume(returning: controller)
        } else {
            available.append(controller)
        }
        return controller
    }

    func nextController() async -> AppleAuthorizationControllerDouble {
        if !available.isEmpty { return available.removeFirst() }
        return await withCheckedContinuation { waiting.append($0) }
    }
}

private final class AppleAuthorizationControllerDouble: AppleAuthorizationPerforming {
    private let completionGate: AppleAuthorizationCompletionGate<AppleSignInCredential>
    private(set) var cancelCount = 0
    private(set) var didReceiveLateCallback = false
    private var completed = false

    init(completionGate: AppleAuthorizationCompletionGate<AppleSignInCredential>) {
        self.completionGate = completionGate
    }

    func perform() {}

    func cancel() {
        cancelCount += 1
        completed = true
        completionGate.resolve(.failure(CancellationError()))
    }

    func succeed(with credential: AppleSignInCredential) {
        if completed { didReceiveLateCallback = true }
        completed = true
        completionGate.resolve(.success(credential))
    }

    func fail(with error: Error) {
        if completed { didReceiveLateCallback = true }
        completed = true
        completionGate.resolve(.failure(error))
    }
}

private extension AppleSignInCredential {
    static func fixture() -> Self {
        Self(
            identityToken: "fictional-identity-token",
            authorizationCode: "fictional-authorization-code",
            rawNonce: "fictional-raw-nonce",
            displayName: nil
        )
    }
}
