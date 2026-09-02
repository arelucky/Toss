import XCTest
@testable import Toss

final class LaunchProfilePresentationTests: XCTestCase {
    @MainActor
    func testMainlandRouteNeverBuildsOnlineDependencies() {
        let factory = OnlineRootFactoryDouble()
        let presentation = LaunchProfilePresentation(
            profile: .mainlandClassicOnly,
            onlineFactory: factory
        )

        XCTAssertEqual(presentation.destination, .mainlandClassicOnly)
        XCTAssertEqual(factory.makeCallCount, 0)
    }

    @MainActor
    func testGlobalRouteBuildsOnlineDependenciesOnce() {
        let factory = OnlineRootFactoryDouble()
        let presentation = LaunchProfilePresentation(
            profile: .globalOnline,
            onlineFactory: factory
        )

        _ = presentation.onlineDependencies
        _ = presentation.onlineDependencies

        XCTAssertEqual(factory.makeCallCount, 1)
    }

    @MainActor
    func testClassicContentHasNoCoinLibraryAction() {
        let view = ContentView(
            viewModel: CoinTossViewModel(),
            coinModelSource: .bundledClassic,
            onOpenCoinLibrary: nil
        )

        XCTAssertFalse(view.showsCoinLibraryControl)
        XCTAssertEqual(view.displayedCoinModelSource, .bundledClassic)
    }
}

@MainActor
private final class OnlineRootFactoryDouble: OnlineRootBuilding {
    private(set) var makeCallCount = 0

    func makeOnlineDependencies() -> AppDependencies {
        makeCallCount += 1
        return .live(configuration: nil)
    }
}
