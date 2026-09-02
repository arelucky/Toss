# Toss Mainland Classic-only Launch Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox syntax for tracking.

**Goal:** Make the single Toss binary select an offline, Classic-only experience for China mainland storefronts while preserving the existing online experience everywhere else.

**Architecture:** A testable asynchronous launch-profile resolver reads a persisted choice first, then awaits `Storefront.current?.countryCode`. `CHN` selects `mainlandClassicOnly`; other known storefronts select `globalOnline`; an unavailable storefront asks once for a manual choice. The mainland root never creates `AppDependencies`, a Supabase client, account services, catalog caches, asset caches, or a coin-library view model.

**Tech Stack:** Swift 5, SwiftUI, StoreKit `Storefront`, XCTest, UserDefaults-backed local preferences, iOS 17 minimum.

**Spec:** `docs/superpowers/specs/2026-08-31-toss-mainland-release-design.md`

## Global Constraints

- Use SwiftUI and MVVM; add no third-party dependency.
- China mainland means the StoreKit ISO alpha-3 country code `CHN`, never device locale, SIM, IP address, VPN state, or time zone.
- Persist the first resolved profile. A later VPN, travel, or network change must not switch it.
- `mainlandClassicOnly` must not initialize Supabase, authentication, account synchronization, catalog loading, model downloading, WebP loading, or their cache directories.
- Mainland exposes Classic toss plus sound and haptic settings only. It must not show disabled account or coin-library controls.
- The global profile retains all current account, coin-library, dynamic-model, download-retry, and selected-coin behavior.
- Do not purchase services, change DNS, submit a filing, enable China mainland in App Store Connect, or alter the overseas Supabase project.
- Each implementation task gets one English Git commit after focused tests pass.

## File Structure

| Path | Responsibility |
|---|---|
| `Toss/Configuration/DistributionProfile.swift` | Profile identity and pure capability values. |
| `Toss/Configuration/DistributionProfileStore.swift` | Persisted choice using `PreferencesKeyValueStoring`. |
| `Toss/Configuration/DistributionProfileResolver.swift` | Storefront mapping and one-time manual fallback. |
| `Toss/Views/AppBootstrapView.swift` | Resolves profile before constructing an app root. |
| `Toss/Views/DistributionProfileChoiceView.swift` | Accessible Mainland / Other regions fallback picker. |
| `Toss/Views/MainlandClassicRootView.swift` | Offline root containing only toss and local settings. |
| `Toss/Views/ClassicSettingsSheetView.swift` | Local sound and haptic controls. |
| `Toss/ViewModels/ClassicSettingsViewModel.swift` | Reads and writes only `LocalPreferencesStore`. |
| `Toss/Views/AppRootView.swift` | Existing global-online root and online-only dependency graph. |
| `Toss/Views/ContentView.swift` | Receives a model source and optional library action from its root. |
| `TossTests/Configuration/DistributionProfileResolverTests.swift` | Resolver and persistence tests without StoreKit or UserDefaults. |
| `TossTests/Views/LaunchProfilePresentationTests.swift` | Proves Mainland does not construct online dependencies. |
| `TossTests/Views/ClassicSettingsViewModelTests.swift` | Proves settings persist and apply locally. |
| `Toss.xcodeproj/project.pbxproj` | New source file references and build-phase entries. |

---

### Task 1: Add deterministic distribution-profile resolution

**Files:**
- Create: `Toss/Configuration/DistributionProfile.swift`
- Create: `Toss/Configuration/DistributionProfileStore.swift`
- Create: `Toss/Configuration/DistributionProfileResolver.swift`
- Create: `TossTests/Configuration/DistributionProfileResolverTests.swift`
- Modify: `Toss.xcodeproj/project.pbxproj`

**Interfaces:**
- `enum DistributionProfile: String, Equatable, Sendable { case globalOnline; case mainlandClassicOnly }`
- `DistributionProfile.capabilities -> DistributionProfileCapabilities(showsCoinLibrary:showsAccount:usesOnlineServices:)`
- `enum DistributionProfileResolution: Equatable { case resolved(DistributionProfile); case requiresManualChoice }`
- `protocol StorefrontCountryCodeProviding { func currentCountryCode() async -> String? }`
- `DistributionProfileStore.storedProfile`, `save(_:)`
- `DistributionProfileResolver.resolve() async`, `chooseManually(_:)`

- [ ] **Step 1: Write failing resolver tests**

~~~swift
func testCHNStorefrontResolvesAndPersistsClassicOnly() async {
    let store = DistributionProfileStore(store: ProfileKeyValueStore())
    let resolver = DistributionProfileResolver(
        store: store,
        storefront: StorefrontCountryCodeDouble(countryCode: "CHN")
    )

    XCTAssertEqual(await resolver.resolve(), .resolved(.mainlandClassicOnly))
    XCTAssertEqual(store.storedProfile, .mainlandClassicOnly)
    XCTAssertFalse(DistributionProfile.mainlandClassicOnly.capabilities.showsCoinLibrary)
    XCTAssertFalse(DistributionProfile.mainlandClassicOnly.capabilities.showsAccount)
    XCTAssertFalse(DistributionProfile.mainlandClassicOnly.capabilities.usesOnlineServices)
}

func testStoredProfileWinsOverChangedStorefront() async {
    let store = DistributionProfileStore(store: ProfileKeyValueStore())
    store.save(.globalOnline)
    let resolver = DistributionProfileResolver(
        store: store,
        storefront: StorefrontCountryCodeDouble(countryCode: "CHN")
    )

    XCTAssertEqual(await resolver.resolve(), .resolved(.globalOnline))
}

func testUnknownStorefrontRequiresManualChoiceAndPersistsIt() async {
    let store = DistributionProfileStore(store: ProfileKeyValueStore())
    let resolver = DistributionProfileResolver(
        store: store,
        storefront: StorefrontCountryCodeDouble(countryCode: nil)
    )

    XCTAssertEqual(await resolver.resolve(), .requiresManualChoice)
    XCTAssertEqual(resolver.chooseManually(.mainlandClassicOnly), .mainlandClassicOnly)
    XCTAssertEqual(store.storedProfile, .mainlandClassicOnly)
}
~~~

- [ ] **Step 2: Verify RED**

Run:

~~~bash
xcodebuild test -project Toss.xcodeproj -scheme Toss \
  -destination 'platform=iOS Simulator,name=iPhone 15 Pro,OS=17.5' \
  -only-testing:TossTests/DistributionProfileResolverTests
~~~

Expected: compilation fails because the profile resolver types do not exist.

- [ ] **Step 3: Implement the resolver**

Use the existing `PreferencesKeyValueStoring` protocol, with a distinct `distribution.profile` key. The StoreKit provider returns `Storefront.current?.countryCode`.

~~~swift
func resolve() async -> DistributionProfileResolution {
    if let storedProfile = store.storedProfile { return .resolved(storedProfile) }
    guard let countryCode = await storefront.currentCountryCode() else { return .requiresManualChoice }
    let profile: DistributionProfile = countryCode.uppercased() == "CHN"
        ? .mainlandClassicOnly
        : .globalOnline
    store.save(profile)
    return .resolved(profile)
}
~~~

Add the source files to the app and `TossTests` build phases using the existing manual `project.pbxproj` file-reference pattern.

- [ ] **Step 4: Verify GREEN**

Re-run Step 2. Expect all resolver tests to pass without any network request.

- [ ] **Step 5: Commit**

~~~bash
git add Toss/Configuration/DistributionProfile.swift Toss/Configuration/DistributionProfileStore.swift Toss/Configuration/DistributionProfileResolver.swift TossTests/Configuration/DistributionProfileResolverTests.swift Toss.xcodeproj/project.pbxproj
git diff --cached --check
git commit -m 'feat: resolve mainland launch profile'
~~~

### Task 2: Bootstrap an offline Mainland root without online dependencies

**Files:**
- Create: `Toss/Views/AppBootstrapView.swift`
- Create: `Toss/Views/DistributionProfileChoiceView.swift`
- Create: `Toss/Views/MainlandClassicRootView.swift`
- Modify: `Toss/App/TossApp.swift`
- Modify: `Toss/Views/AppRootView.swift`
- Create: `TossTests/Views/LaunchProfilePresentationTests.swift`
- Modify: `Toss.xcodeproj/project.pbxproj`

**Interfaces:**
- `protocol OnlineRootBuilding { @MainActor func makeOnlineDependencies() -> AppDependencies }`
- `LaunchProfilePresentation(profile:onlineFactory:)` caches global dependencies once and exposes `.mainlandClassicOnly`, `.globalOnline`, or `.requiresManualChoice` destination.
- `AppBootstrapView` resolves before creating either root.

- [ ] **Step 1: Write failing route tests**

~~~swift
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
    let presentation = LaunchProfilePresentation(profile: .globalOnline, onlineFactory: factory)

    _ = presentation.onlineDependencies
    _ = presentation.onlineDependencies
    XCTAssertEqual(factory.makeCallCount, 1)
}
~~~

- [ ] **Step 2: Verify RED**

~~~bash
xcodebuild test -project Toss.xcodeproj -scheme Toss \
  -destination 'platform=iOS Simulator,name=iPhone 15 Pro,OS=17.5' \
  -only-testing:TossTests/LaunchProfilePresentationTests
~~~

Expected: compilation fails because bootstrap presentation and factory types do not exist.

- [ ] **Step 3: Implement bootstrap**

`TossApp` must render `AppBootstrapView()`, not `AppRootView(dependencies: .live())`. `AppBootstrapView` invokes `await resolver.resolve()` from its `.task`, and it must show only a neutral launch progress state while this short StoreKit read is unfinished.

~~~swift
switch presentation.destination {
case .mainlandClassicOnly:
    MainlandClassicRootView()
case .globalOnline:
    AppRootView(dependencies: presentation.onlineDependencies)
case .requiresManualChoice:
    DistributionProfileChoiceView(onChoose: presentation.chooseManually)
}
~~~

Keep the current `AppRootView(dependencies:)` as the global-only root. Its account restoration task stays inside this branch. `MainlandClassicRootView` must not import or reference `AppDependencies`, `AccountStore`, `AccountViewModel`, `CoinLibraryViewModel`, `CoinCatalogCache`, `CoinAssetCache`, `SupabaseConfiguration`, or `AppDependencies.live()`.

- [ ] **Step 4: Verify GREEN**

Re-run Step 2. Inspect the mainland constructor: it accepts no online service dependency.

- [ ] **Step 5: Commit**

~~~bash
git add Toss/Views/AppBootstrapView.swift Toss/Views/DistributionProfileChoiceView.swift Toss/Views/MainlandClassicRootView.swift Toss/App/TossApp.swift Toss/Views/AppRootView.swift TossTests/Views/LaunchProfilePresentationTests.swift Toss.xcodeproj/project.pbxproj
git diff --cached --check
git commit -m 'feat: add mainland offline app root'
~~~

### Task 3: Hide online controls and retain local sound and haptic settings

**Files:**
- Create: `Toss/ViewModels/ClassicSettingsViewModel.swift`
- Create: `Toss/Views/ClassicSettingsSheetView.swift`
- Modify: `Toss/Views/MainlandClassicRootView.swift`
- Modify: `Toss/Views/ContentView.swift`
- Modify: `Toss/Views/AppRootView.swift`
- Modify: `TossTests/TossTests.swift`
- Create: `TossTests/Views/ClassicSettingsViewModelTests.swift`
- Modify: `Toss.xcodeproj/project.pbxproj`

**Interfaces:**
- `ClassicSettingsViewModel` publishes `soundEnabled` and `hapticEnabled`, and implements `setSoundEnabled(_:)` / `setHapticEnabled(_:)`.
- `ContentView` accepts `coinModelSource: CoinModelSource` and `onOpenCoinLibrary: (() -> Void)?`.
- `ContentView.showsCoinLibraryControl` returns whether that callback exists.
- Mainland always uses `.bundledClassic` and `nil`; the global root supplies the selected source and its existing library action.

- [ ] **Step 1: Write failing local-settings and control tests**

~~~swift
@MainActor
func testClassicSettingsPersistAndApplyFeedbackLocally() {
    let storage = SettingsKeyValueStore()
    let feedback = FeedbackDouble()
    let model = ClassicSettingsViewModel(
        localPreferences: LocalPreferencesStore(store: storage),
        feedbackPreferences: feedback
    )

    model.setSoundEnabled(false)
    model.setHapticEnabled(false)

    XCTAssertFalse(model.soundEnabled)
    XCTAssertFalse(model.hapticEnabled)
    XCTAssertEqual(feedback.applied, .init(soundEnabled: false, hapticEnabled: false))
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
~~~

- [ ] **Step 2: Verify RED**

~~~bash
xcodebuild test -project Toss.xcodeproj -scheme Toss \
  -destination 'platform=iOS Simulator,name=iPhone 15 Pro,OS=17.5' \
  -only-testing:TossTests/ClassicSettingsViewModelTests \
  -only-testing:TossTests/TossTests/testClassicContentHasNoCoinLibraryAction
~~~

Expected: compilation fails because the revised ContentView and settings view model do not exist.

- [ ] **Step 3: Implement the local-only settings and ownership split**

`ClassicSettingsViewModel` reads `LocalPreferencesStore.guestPreferences`, saves only `saveGuest`, then calls `AppFeedbackPreferencesController.apply`. It must not accept or reference an account service, repository, sync coordinator, or Supabase type.

Move the online full-screen `CoinLibraryView` presentation from `ContentView` into `AppRootView`. `ContentView` shows its grid button only if the action exists:

~~~swift
var showsCoinLibraryControl: Bool { onOpenCoinLibrary != nil }

if let onOpenCoinLibrary {
    Button(action: onOpenCoinLibrary) {
        Image(systemName: "circle.grid.2x2.fill")
            .font(.system(size: 18, weight: .medium))
            .frame(width: TossVisualStyle.controlSize, height: TossVisualStyle.controlSize)
    }
}
~~~

`MainlandClassicRootView` supplies `.bundledClassic`, no library action, and a sliders button opening `ClassicSettingsSheetView`. Reuse `AccountPreferenceRow` for only Sound and Haptics. It must not present `AccountSheetView`.

- [ ] **Step 4: Verify GREEN**

Run Step 2, then:

~~~bash
xcodebuild test -project Toss.xcodeproj -scheme Toss \
  -destination 'platform=iOS Simulator,name=iPhone 15 Pro,OS=17.5' \
  -only-testing:TossTests/CoinLibraryViewModelTests/testContentViewUsesSelectedDownloadedModelSource \
  -only-testing:TossTests/TossTests/testHomeIdleAffordanceIsVisibleOnlyWhileIdle
~~~

Expected: all focused tests pass, including the unchanged global dynamic-selection behavior.

- [ ] **Step 5: Commit**

~~~bash
git add Toss/ViewModels/ClassicSettingsViewModel.swift Toss/Views/ClassicSettingsSheetView.swift Toss/Views/MainlandClassicRootView.swift Toss/Views/ContentView.swift Toss/Views/AppRootView.swift TossTests/TossTests.swift TossTests/Views/ClassicSettingsViewModelTests.swift Toss.xcodeproj/project.pbxproj
git diff --cached --check
git commit -m 'feat: limit mainland app to Classic'
~~~

### Task 4: Validate both profiles and document the release state

**Files:**
- Modify: `SPRINTS.md`
- Modify: `docs/superpowers/plans/2026-08-31-toss-mainland-release-implementation.md`

- [ ] **Step 1: Mark the prior cloud-deployment plan as superseded**

Add this notice to the top of the old plan:

~~~markdown
> **Superseded on 2026-09-02.** China mainland first release is Classic-only and does not deploy domestic online services. Do not execute this plan; use `2026-09-02-mainland-classic-only-launch.md`.
~~~

- [ ] **Step 2: Run the complete automated gate once**

~~~bash
xcodebuild test -project Toss.xcodeproj -scheme Toss \
  -destination 'platform=iOS Simulator,name=iPhone 15 Pro,OS=17.5' \
  -only-testing:TossTests
xcodebuild build -project Toss.xcodeproj -scheme Toss \
  -destination 'platform=iOS Simulator,name=iPhone 15 Pro,OS=17.5'
git diff --check
~~~

Expected: all TossTests pass, Debug simulator build succeeds, and the diff check has no output.

- [ ] **Step 3: Obtain user visual confirmation for both profiles**

Mainland profile (with network disabled): cold-launch, confirm only Classic, settings, sound, haptics, and toss are reachable; no account icon, coin-library icon, loading state, or online request appears.

Global profile: confirm account and coin-library buttons remain visible; choose an already-downloaded dynamic coin; confirm it remains the homepage model after returning.

If Storefront cannot be forced on a device, use the one-time manual picker and then clear only the `distribution.profile` test preference before the second check. Do not change Apple ID settings.

- [ ] **Step 4: Append the Sprint record only after user approval**

Append `中国大陆 Classic-only 首发阶段` stating that Mainland has bundled Classic and local sound/haptic preferences, that online dependencies and controls are not initialized there, and that the global route passed the full TossTests suite.

- [ ] **Step 5: Commit the final documentation**

~~~bash
git add SPRINTS.md docs/superpowers/plans/2026-08-31-toss-mainland-release-implementation.md
git diff --cached --check
git commit -m 'docs: record mainland Classic-only launch'
~~~
