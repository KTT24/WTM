import Foundation

enum VenueKind: String, Codable, Equatable {
    case bar
    case event
    case direct

    var friendlyName: String {
        switch self {
        case .bar:
            return "Bar"
        case .event:
            return "Party"
        case .direct:
            return "DM"
        }
    }
}

struct VenueSnapshot: Equatable {
    let identifier: String
    let title: String
    let subtitle: String
    let kind: VenueKind
}

struct FriendProfile: Identifiable, Codable, Equatable {
    let id: UUID
    var displayName: String
    var username: String
    var currentHangout: String
    var currentHangoutKind: VenueKind
    var lastSeenLabel: String
    var mutualFriends: Int
    var note: String
    var addedAt: Date

    var conversationSubtitle: String {
        "\(currentHangout) · \(lastSeenLabel)"
    }

    var initials: String {
        let pieces = displayName.split(separator: " ").prefix(2)
        let letters = pieces.compactMap { $0.first }
        return String(letters.prefix(2)).uppercased()
    }
}

struct VenueParticipant: Identifiable, Equatable {
    let id: UUID
    let displayName: String
    let username: String
    let venueTitle: String
    let venueKind: VenueKind
    let lastSeenLabel: String
    let mutualFriends: Int
    let note: String
    let isFriend: Bool
    let friendID: UUID?

    var summary: String {
        "\(note) · \(lastSeenLabel)"
    }

    var initials: String {
        let pieces = displayName.split(separator: " ").prefix(2)
        let letters = pieces.compactMap { $0.first }
        return String(letters.prefix(2)).uppercased()
    }
}
