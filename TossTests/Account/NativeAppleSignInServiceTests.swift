import AuthenticationServices
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
}
