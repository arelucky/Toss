import XCTest
@testable import Toss

final class AccountStoreTests: XCTestCase {
    func testValidConfigurationBuildsOneSharedClientBackedGraph() throws {
        let configuration = SupabaseConfiguration(
            url: try XCTUnwrap(URL(string: "http://127.0.0.1:54321")),
            publishableKey: "public-test-key"
        )

        let dependencies = AppDependencies.live(configuration: configuration)

        XCTAssertNotNil(dependencies.environment)
        XCTAssertEqual(dependencies.session, .guest)
        XCTAssertEqual(Set(dependencies.clientEnvironmentIdentities).count, 1)
        XCTAssertEqual(dependencies.clientEnvironmentIdentities.count, 4)
    }

    func testMissingConfigurationBuildsOfflineGuestGraph() {
        let dependencies = AppDependencies.live(configuration: nil)

        XCTAssertNil(dependencies.environment)
        XCTAssertEqual(dependencies.session, .guest)
    }

    func testBlankConfigurationBuildsOfflineGuestGraph() throws {
        let bundle = try makeBundle(info: [
            "TossSupabaseURL": "   ",
            "TossSupabasePublishableKey": "public-test-key"
        ])

        let dependencies = AppDependencies.live(bundle: bundle)

        XCTAssertNil(dependencies.environment)
        XCTAssertEqual(dependencies.session, .guest)
    }

    func testOfflineDependenciesFailOnlyWhenAnOperationIsRequested() async {
        let dependencies = AppDependencies.live(configuration: nil)

        do {
            _ = try await dependencies.authService.restoredSession()
            XCTFail("Expected the offline account dependency to be unavailable")
        } catch {
            XCTAssertEqual(error as? AccountDependencyError, .unavailable)
        }
    }

    func testAccountTestDoublesConformWithoutNetworking() async throws {
        let doubles = AccountTestDoubles()

        let restoredSession = try await doubles.authService.restoredSession()

        XCTAssertEqual(restoredSession, .guest)
        XCTAssertEqual(doubles.profileRepository.callCount, 0)
        XCTAssertEqual(doubles.preferencesRepository.callCount, 0)
        XCTAssertEqual(doubles.deletionService.callCount, 0)
    }

    private func makeBundle(info: [String: String]) throws -> Bundle {
        let bundleURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("bundle")
        try FileManager.default.createDirectory(at: bundleURL, withIntermediateDirectories: true)
        let data = try PropertyListSerialization.data(
            fromPropertyList: info,
            format: .xml,
            options: 0
        )
        try data.write(to: bundleURL.appendingPathComponent("Info.plist"))
        addTeardownBlock { try? FileManager.default.removeItem(at: bundleURL) }
        return try XCTUnwrap(Bundle(url: bundleURL))
    }
}
