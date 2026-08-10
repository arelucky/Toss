import AVFoundation
import Foundation

enum TossSoundEffect: String, CaseIterable {
    case coinThrow = "coin_throw"
    case coinAirSpin = "coin_air_spin"

    var fileName: String {
        rawValue
    }

    var fileExtension: String {
        "wav"
    }
}

final class SoundManager {
    static let shared = SoundManager()

    private let bundle: Bundle
    private(set) var isEnabled: Bool
    private var players: [TossSoundEffect: AVAudioPlayer] = [:]
    private var isAudioSessionConfigured = false

    init(bundle: Bundle = .main, isEnabled: Bool = true) {
        self.bundle = bundle
        self.isEnabled = isEnabled
    }

    func setEnabled(_ enabled: Bool) {
        isEnabled = enabled
        if !enabled { players.values.forEach { $0.stop() } }
    }

    func prepare(_ effects: [TossSoundEffect] = TossSoundEffect.allCases) {
        guard isEnabled else { return }
        configureAudioSessionIfNeeded()

        for effect in effects where players[effect] == nil {
            guard let player = makePlayer(for: effect) else { continue }
            players[effect] = player
        }
    }

    func play(_ effect: TossSoundEffect) {
        guard isEnabled else { return }
        configureAudioSessionIfNeeded()

        let player = players[effect] ?? makePlayer(for: effect)
        guard let player else { return }

        players[effect] = player
        player.currentTime = 0
        player.play()
    }

    private func makePlayer(for effect: TossSoundEffect) -> AVAudioPlayer? {
        guard let url = resourceURL(for: effect) else {
            TossDebugLog.log("SoundManager", "missing sound: \(effect.fileName).\(effect.fileExtension)")
            return nil
        }

        do {
            let player = try AVAudioPlayer(contentsOf: url)
            player.prepareToPlay()
            return player
        } catch {
            TossDebugLog.log("SoundManager", "failed to load \(effect.fileName): \(error.localizedDescription)")
            return nil
        }
    }

    private func resourceURL(for effect: TossSoundEffect) -> URL? {
        bundle.url(
            forResource: effect.fileName,
            withExtension: effect.fileExtension,
            subdirectory: "Sounds"
        ) ?? bundle.url(
            forResource: effect.fileName,
            withExtension: effect.fileExtension,
            subdirectory: "Resources/Sounds"
        ) ?? bundle.url(
            forResource: effect.fileName,
            withExtension: effect.fileExtension
        )
    }

    private func configureAudioSessionIfNeeded() {
        guard !isAudioSessionConfigured else { return }

        do {
            try AVAudioSession.sharedInstance().setCategory(.ambient, options: [.mixWithOthers])
            isAudioSessionConfigured = true
        } catch {
            TossDebugLog.log("SoundManager", "failed to configure audio session: \(error.localizedDescription)")
        }
    }
}
