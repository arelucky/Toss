import Foundation

struct UserPreferences: Codable, Equatable {
    let userID: UUID
    let soundEnabled: Bool
    let hapticEnabled: Bool
    let createdAt: Date
    let updatedAt: Date

    var localValue: LocalPreferences {
        LocalPreferences(soundEnabled: soundEnabled, hapticEnabled: hapticEnabled)
    }

    enum CodingKeys: String, CodingKey {
        case userID = "user_id"
        case soundEnabled = "sound_enabled"
        case hapticEnabled = "haptic_enabled"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

struct LocalPreferences: Codable, Equatable {
    let soundEnabled: Bool
    let hapticEnabled: Bool

    static let defaults = LocalPreferences(soundEnabled: true, hapticEnabled: true)
}
