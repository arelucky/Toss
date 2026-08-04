import Foundation

enum AccountSession: Equatable {
    case guest
    case restoring
    case authenticated(userID: UUID)
}
