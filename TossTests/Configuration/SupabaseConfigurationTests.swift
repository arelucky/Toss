import XCTest
@testable import Toss

final class SupabaseConfigurationTests: XCTestCase {
    func testLoadReturnsValidPublicConfiguration() throws {
        let bundle = try makeBundle(info: [
            "TossSupabaseURL": "http://127.0.0.1:54321",
            "TossSupabasePublishableKey": "sb_publishable_local_test"
        ])

        let configuration = try SupabaseConfiguration.load(from: bundle)

        XCTAssertEqual(configuration.url, URL(string: "http://127.0.0.1:54321"))
        XCTAssertEqual(configuration.publishableKey, "sb_publishable_local_test")
    }

    func testLoadRejectsMissingValues() throws {
        let bundle = try makeBundle(info: [:])

        XCTAssertThrowsError(try SupabaseConfiguration.load(from: bundle)) { error in
            XCTAssertEqual(error as? SupabaseConfigurationError, .missingValue("TossSupabaseURL"))
        }
    }

    func testLoadRejectsBlankValues() throws {
        let bundle = try makeBundle(info: [
            "TossSupabaseURL": "   ",
            "TossSupabasePublishableKey": "sb_publishable_local_test"
        ])

        XCTAssertThrowsError(try SupabaseConfiguration.load(from: bundle)) { error in
            XCTAssertEqual(error as? SupabaseConfigurationError, .missingValue("TossSupabaseURL"))
        }
    }

    func testLoadRejectsMalformedURL() throws {
        let bundle = try makeBundle(info: [
            "TossSupabaseURL": "not a url",
            "TossSupabasePublishableKey": "sb_publishable_local_test"
        ])

        XCTAssertThrowsError(try SupabaseConfiguration.load(from: bundle)) { error in
            XCTAssertEqual(error as? SupabaseConfigurationError, .invalidURL)
        }
    }

    func testLoadRejectsSecretKeyPrefix() throws {
        let bundle = try makeBundle(info: [
            "TossSupabaseURL": "http://127.0.0.1:54321",
            "TossSupabasePublishableKey": "sb_secret_forbidden"
        ])

        XCTAssertThrowsError(try SupabaseConfiguration.load(from: bundle)) { error in
            XCTAssertEqual(error as? SupabaseConfigurationError, .prohibitedKey)
        }
    }

    func testLoadRejectsLegacyServiceRoleJWT() throws {
        let payload = Data(#"{"role":"service_role"}"#.utf8)
            .base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
        let bundle = try makeBundle(info: [
            "TossSupabaseURL": "http://127.0.0.1:54321",
            "TossSupabasePublishableKey": "header.\(payload).signature"
        ])

        XCTAssertThrowsError(try SupabaseConfiguration.load(from: bundle)) { error in
            XCTAssertEqual(error as? SupabaseConfigurationError, .prohibitedKey)
        }
    }

    func testSecretTemplateAndIgnoreRulesAreSafe() throws {
        let repositoryRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let gitignore = try String(
            contentsOf: repositoryRoot.appendingPathComponent(".gitignore"),
            encoding: .utf8
        )
        let example = try String(
            contentsOf: repositoryRoot.appendingPathComponent("Configurations/LocalSecrets.xcconfig.example"),
            encoding: .utf8
        )

        XCTAssertTrue(gitignore.contains("/Configurations/LocalSecrets.xcconfig"))
        XCTAssertTrue(gitignore.contains("supabase/.temp/"))
        XCTAssertTrue(gitignore.contains("supabase/.branches/"))
        XCTAssertEqual(
            example.split(separator: "\n", omittingEmptySubsequences: false).map(String.init),
            ["SUPABASE_URL =", "SUPABASE_PUBLISHABLE_KEY =", ""]
        )
    }

    private func makeBundle(info: [String: String]) throws -> Bundle {
        let bundleURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("bundle")
        try FileManager.default.createDirectory(at: bundleURL, withIntermediateDirectories: true)
        let infoURL = bundleURL.appendingPathComponent("Info.plist")
        let data = try PropertyListSerialization.data(
            fromPropertyList: info,
            format: .xml,
            options: 0
        )
        try data.write(to: infoURL)
        addTeardownBlock {
            try? FileManager.default.removeItem(at: bundleURL)
        }
        return try XCTUnwrap(Bundle(url: bundleURL))
    }
}
