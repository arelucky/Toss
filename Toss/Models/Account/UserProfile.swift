import Foundation

enum UserProfileStatus: String, Codable, Equatable {
    case active
    case disabled
    case deleted
}

struct UserProfile: Codable, Equatable {
    let id: UUID
    let displayName: String?
    let status: UserProfileStatus
    let createdAt: Date
    let updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case displayName = "display_name"
        case status
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}
