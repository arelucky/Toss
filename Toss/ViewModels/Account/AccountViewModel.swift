import Combine
import Foundation

enum AccountPresentation: Equatable {
    case guest
    case restoring
    case authenticated(displayName: String)
}

enum AccountNotice: Equatable {
    case restorationFailed
    case signInFailed
    case syncDeferred
    case remoteSignOutDeferred
    case signOutFailed

    var message: String {
        switch self {
        case .restorationFailed: "Couldn’t restore your account. Toss is still available."
        case .signInFailed: "Sign in couldn’t be completed. Please try again."
        case .syncDeferred: "Changes are saved on this device and will sync when connection returns."
        case .remoteSignOutDeferred: "Signed out on this device. Remote session cleanup will finish later."
        case .signOutFailed: "Couldn’t safely sign out on this device. Your account remains signed in."
        }
    }
}

@MainActor
final class AccountViewModel: ObservableObject {
    static let fallbackDisplayName = "Toss Account"

    @Published private(set) var displayName: String?
    @Published private(set) var soundEnabled: Bool
    @Published private(set) var hapticEnabled: Bool
    @Published private(set) var notice: AccountNotice?
    @Published private(set) var isSigningIn = false
    @Published private(set) var isSigningOut = false

    private let accountStore: AccountStore
    private let appleSignInService: any AppleSignInServicing
    private let profileRepository: any UserProfileRepository
    private let syncCoordinator: AccountSyncCoordinator
    private let localPreferences: LocalPreferencesStore
    private let feedbackPreferences: any FeedbackPreferenceApplying
    private var accountObservation: AnyCancellable?
    private var hasStarted = false

    var presentation: AccountPresentation {
        switch accountStore.session {
        case .guest: .guest
        case .restoring: .restoring
        case .authenticated: .authenticated(displayName: displayName ?? Self.fallbackDisplayName)
        }
    }

    init(
        accountStore: AccountStore,
        appleSignInService: any AppleSignInServicing,
        profileRepository: any UserProfileRepository,
        syncCoordinator: AccountSyncCoordinator,
        localPreferences: LocalPreferencesStore,
        feedbackPreferences: any FeedbackPreferenceApplying
    ) {
        self.accountStore = accountStore
        self.appleSignInService = appleSignInService
        self.profileRepository = profileRepository
        self.syncCoordinator = syncCoordinator
        self.localPreferences = localPreferences
        self.feedbackPreferences = feedbackPreferences
        let initial = localPreferences.guestPreferences
        soundEnabled = initial.soundEnabled
        hapticEnabled = initial.hapticEnabled
        accountObservation = accountStore.objectWillChange.sink { [weak self] _ in
            self?.objectWillChange.send()
        }
    }

    func start() async {
        guard !hasStarted else { return }
        hasStarted = true
        await accountStore.restoreSession()
        if accountStore.error == .restorationFailed { notice = .restorationFailed }
        await refreshAuthenticatedAccount()
    }

    func signIn() async {
        guard !isSigningIn else { return }
        isSigningIn = true
        notice = nil
        defer { isSigningIn = false }
        await accountStore.signInWithApple(using: appleSignInService)
        if accountStore.error == .signInFailed {
            notice = .signInFailed
            return
        }
        await refreshAuthenticatedAccount()
    }

    func refreshAuthenticatedAccount() async {
        guard case let .authenticated(userID) = accountStore.session else {
            displayName = nil
            let guest = localPreferences.guestPreferences
            soundEnabled = guest.soundEnabled
            hapticEnabled = guest.hapticEnabled
            return
        }
        await syncCoordinator.synchronize(for: userID)
        if let cached = localPreferences.cachedPreferences(for: userID) {
            soundEnabled = cached.soundEnabled
            hapticEnabled = cached.hapticEnabled
        }
        do {
            let profile = try await profileRepository.fetch(userID: userID)
            let normalized = profile.displayName?.trimmingCharacters(in: .whitespacesAndNewlines)
            displayName = normalized?.isEmpty == false ? normalized : nil
        } catch {
            displayName = nil
        }
        notice = syncCoordinator.preferencesSyncFailed ? .syncDeferred : nil
    }

    func setSoundEnabled(_ enabled: Bool) async {
        soundEnabled = enabled
        await applyPreferences()
    }

    func setHapticEnabled(_ enabled: Bool) async {
        hapticEnabled = enabled
        await applyPreferences()
    }

    func signOut() async {
        guard !isSigningOut else { return }
        isSigningOut = true
        notice = nil
        defer { isSigningOut = false }
        let result = await accountStore.signOut()
        guard accountStore.session == .guest, let result else {
            notice = .signOutFailed
            return
        }
        syncCoordinator.didSignOut()
        displayName = nil
        let guest = localPreferences.guestPreferences
        soundEnabled = guest.soundEnabled
        hapticEnabled = guest.hapticEnabled
        notice = result == .deferred ? .remoteSignOutDeferred : nil
    }

    func clearNotice() {
        notice = nil
    }

    private func applyPreferences() async {
        let preferences = LocalPreferences(soundEnabled: soundEnabled, hapticEnabled: hapticEnabled)
        switch accountStore.session {
        case let .authenticated(userID):
            await syncCoordinator.updatePreferences(preferences, for: userID)
            if syncCoordinator.preferencesSyncFailed { notice = .syncDeferred }
        case .guest, .restoring:
            localPreferences.saveGuest(preferences)
            feedbackPreferences.apply(preferences)
        }
    }
}
