import XCTest
@testable import Toss

final class NonceGeneratorTests: XCTestCase {
    func testGenerateReturnsRequestedLengthUsingAllowedCharacters() throws {
        let generator = NonceGenerator(randomBytes: { count in
            Array(repeating: 0, count: count)
        })

        let nonce = try generator.generate(length: 32)

        XCTAssertEqual(nonce.count, 32)
        XCTAssertEqual(nonce, String(repeating: "0", count: 32))
        XCTAssertTrue(nonce.allSatisfy(NonceGenerator.allowedCharacters.contains))
    }

    func testGenerateUsesEveryRandomByteToSelectACharacter() throws {
        let generator = NonceGenerator(randomBytes: { _ in [0, 1, 2, 3] })

        let nonce = try generator.generate(length: 4)

        XCTAssertEqual(nonce, "0123")
    }

    func testGenerateRejectsInvalidLength() {
        let generator = NonceGenerator(randomBytes: { _ in [] })

        XCTAssertThrowsError(try generator.generate(length: 0)) { error in
            XCTAssertEqual(error as? NonceGenerationError, .invalidLength)
        }
    }

    func testGeneratePropagatesSecureRandomFailure() {
        let generator = NonceGenerator(randomBytes: { _ in
            throw NonceGenerationError.secureRandomFailure
        })

        XCTAssertThrowsError(try generator.generate()) { error in
            XCTAssertEqual(error as? NonceGenerationError, .secureRandomFailure)
        }
    }

    func testLiveGeneratorDoesNotReturnFixedValues() throws {
        let generator = NonceGenerator()

        let first = try generator.generate()
        let second = try generator.generate()

        XCTAssertFalse(first.isEmpty)
        XCTAssertNotEqual(first, second)
    }

    func testSHA256MatchesKnownVector() {
        XCTAssertEqual(
            NonceGenerator.sha256("abc"),
            "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad"
        )
    }
}
