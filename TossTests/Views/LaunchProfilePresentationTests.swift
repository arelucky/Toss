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

    func testProfileResolutionLoadingMatchesStaticLaunchScreen() {
        XCTAssertEqual(LaunchProfileLoadingPresentation.backgroundColor, TossVisualStyle.charcoalTop)
        XCTAssertEqual(LaunchProfileLoadingPresentation.title, "命运的一掷")
        XCTAssertEqual(LaunchProfileLoadingPresentation.subtitle, "A toss of fate")
    }

    func testMainlandFilingDisclosureUsesIssuedNumberAndMIITLookup() {
        XCTAssertEqual(
            MainlandAppFilingDisclosure.current.number,
            "苏ICP备2026011580号-2A"
        )
        XCTAssertEqual(
            MainlandAppFilingDisclosure.current.verificationURL,
            URL(string: "https://beian.miit.gov.cn/")
        )
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
