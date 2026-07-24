import Foundation

final class FriendService {
    private enum Keys {
        static let friends = "wtm_friends"
    }

    private struct Persona {
        let displayName: String
        let username: String
        let note: String
        let lastSeenLabel: String
        let mutualFriends: Int
    }

    private let defaults: UserDefaults
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    private let personas: [Persona] = [
        Persona(displayName: "Ava Brooks", username: "@ava.afterhours", note: "On the patio", lastSeenLabel: "3m ago", mutualFriends: 4),
        Persona(displayName: "Miles Reed", username: "@miles.moves", note: "By the bar", lastSeenLabel: "5m ago", mutualFriends: 2),
        Persona(displayName: "Jules Carter", username: "@jules.nights", note: "Near the DJ booth", lastSeenLabel: "7m ago", mutualFriends: 3),
        Persona(displayName: "Nova Kim", username: "@nova.spin", note: "Grabbing a drink", lastSeenLabel: "9m ago", mutualFriends: 1),
        Persona(displayName: "Riley Stone", username: "@riley.runs.it", note: "At the high tops", lastSeenLabel: "12m ago", mutualFriends: 5),
        Persona(displayName: "Theo Lane", username: "@theo.tracks", note: "Outside for air", lastSeenLabel: "14m ago", mutualFriends: 2),
        Persona(displayName: "Zuri Bell", username: "@zuri.nights", note: "With the birthday crew", lastSeenLabel: "4m ago", mutualFriends: 6),
        Persona(displayName: "Leo Park", username: "@leo.late", note: "Saving a booth", lastSeenLabel: "6m ago", mutualFriends: 3)
    ]

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func loadFriends() -> [FriendProfile] {
        guard let data = defaults.data(forKey: Keys.friends),
              let decoded = try? decoder.decode([FriendProfile].self, from: data) else {
            return []
        }
        return decoded.sorted { lhs, rhs in
            if lhs.addedAt != rhs.addedAt {
                return lhs.addedAt > rhs.addedAt
            }
            return lhs.displayName.localizedCaseInsensitiveCompare(rhs.displayName) == .orderedAscending
        }
    }

    func saveFriends(_ friends: [FriendProfile]) throws {
        let data = try encoder.encode(friends)
        defaults.set(data, forKey: Keys.friends)
    }

    func addFriend(from participant: VenueParticipant, existingFriends: [FriendProfile]) throws -> FriendProfile {
        let now = Date()
        let profile = FriendProfile(
            id: participant.friendID ?? participant.id,
            displayName: participant.displayName,
            username: participant.username,
            currentHangout: participant.venueTitle,
            currentHangoutKind: participant.venueKind,
            lastSeenLabel: participant.lastSeenLabel,
            mutualFriends: participant.mutualFriends,
            note: participant.note,
            addedAt: now
        )

        var friends = existingFriends
        if let index = friends.firstIndex(where: { $0.id == profile.id || $0.username.caseInsensitiveCompare(profile.username) == .orderedSame }) {
            friends[index] = profile
        } else {
            friends.insert(profile, at: 0)
        }
        try saveFriends(friends)
        return profile
    }

    func removeFriend(id: UUID, existingFriends: [FriendProfile]) throws {
        let filtered = existingFriends.filter { $0.id != id }
        try saveFriends(filtered)
    }

    func participants(for snapshot: VenueSnapshot, friends: [FriendProfile]) -> [VenueParticipant] {
        guard snapshot.kind != .direct else { return [] }

        let roster = personasForSnapshot(snapshot)
        return roster.map { persona in
            let seed = "\(snapshot.identifier)|\(persona.username)"
            let participantID = BarIDGenerator.deterministicUUID(seed: seed)
            let matchedFriend = friends.first { friend in
                friend.username.caseInsensitiveCompare(persona.username) == .orderedSame ||
                friend.displayName.caseInsensitiveCompare(persona.displayName) == .orderedSame
            }

            return VenueParticipant(
                id: matchedFriend?.id ?? participantID,
                displayName: persona.displayName,
                username: persona.username,
                venueTitle: snapshot.title,
                venueKind: snapshot.kind,
                lastSeenLabel: persona.lastSeenLabel,
                mutualFriends: persona.mutualFriends,
                note: persona.note,
                isFriend: matchedFriend != nil,
                friendID: matchedFriend?.id
            )
        }
    }

    private func personasForSnapshot(_ snapshot: VenueSnapshot) -> [Persona] {
        let desiredCount = 4 + stableInt(seed: snapshot.identifier, salt: "count", upperBound: 3)
        let ranked = personas.enumerated().sorted { lhs, rhs in
            score(seed: snapshot.identifier, value: lhs.element.username) < score(seed: snapshot.identifier, value: rhs.element.username)
        }

        return Array(ranked.prefix(desiredCount)).map(\.element)
    }

    private func score(seed: String, value: String) -> Int {
        "\(seed)|\(value)".unicodeScalars.reduce(into: 0) { partialResult, scalar in
            partialResult = partialResult &* 31 &+ Int(scalar.value)
        }
    }

    private func stableInt(seed: String, salt: String, upperBound: Int) -> Int {
        guard upperBound > 0 else { return 0 }
        let total = "\(seed)|\(salt)".unicodeScalars.reduce(into: 0) { partialResult, scalar in
            partialResult = partialResult &* 33 &+ Int(scalar.value)
        }
        return abs(total) % upperBound
    }
}
