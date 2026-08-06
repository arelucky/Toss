import CryptoKit
import Foundation
import Security

enum NonceGenerationError: Error, Equatable {
    case invalidLength
    case secureRandomFailure
}

struct NonceGenerator {
    static let allowedCharacters = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")

    private let randomBytes: (Int) throws -> [UInt8]

    init(randomBytes: @escaping (Int) throws -> [UInt8] = Self.secureRandomBytes) {
        self.randomBytes = randomBytes
    }

    func generate(length: Int = 32) throws -> String {
        guard length > 0 else { throw NonceGenerationError.invalidLength }
        let bytes = try randomBytes(length)
        guard bytes.count == length else { throw NonceGenerationError.secureRandomFailure }
        return String(bytes.map { Self.allowedCharacters[Int($0) % Self.allowedCharacters.count] })
    }

    static func sha256(_ value: String) -> String {
        SHA256.hash(data: Data(value.utf8)).map { String(format: "%02x", $0) }.joined()
    }

    private static func secureRandomBytes(count: Int) throws -> [UInt8] {
        var bytes = [UInt8](repeating: 0, count: count)
        let status = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        guard status == errSecSuccess else { throw NonceGenerationError.secureRandomFailure }
        return bytes
    }
}
