import Foundation
import Testing
@testable import WTM

struct FriendServiceTests {
    @Test func addFriendPersistsToDefaults() throws {
        let suiteName = UUID().uuidString
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let service = FriendService(defaults: defaults)
        let participant = VenueParticipant(
            id: UUID(),
            displayName: "Ava Brooks",
            username: "@ava.afterhours",
            venueTitle: "Midtown Bar",
            venueKind: .bar,
            lastSeenLabel: "3m ago",
            mutualFriends: 4,
            note: "On the patio",
            isFriend: false,
            friendID: nil
        )

        _ = try service.addFriend(from: participant, existingFriends: [])
        let friends = service.loadFriends()

        #expect(friends.count == 1)
        #expect(friends.first?.displayName == "Ava Brooks")
        #expect(friends.first?.conversationSubtitle == "Midtown Bar · 3m ago")
    }

    @Test func venueParticipantsMarkFriends() throws {
        let suiteName = UUID().uuidString
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let service = FriendService(defaults: defaults)
        let friend = FriendProfile(
            id: UUID(),
            displayName: "Ava Brooks",
            username: "@ava.afterhours",
            currentHangout: "Midtown Bar",
            currentHangoutKind: .bar,
            lastSeenLabel: "3m ago",
            mutualFriends: 4,
            note: "On the patio",
            addedAt: .now
        )
        try service.saveFriends([friend])

        let snapshot = VenueSnapshot(identifier: "bar-123", title: "Midtown Bar", subtitle: "Open now", kind: .bar)
        let participants = service.participants(for: snapshot, friends: service.loadFriends())

        #expect(!participants.isEmpty)
        #expect(participants.first(where: { $0.username == "@ava.afterhours" })?.isFriend == true)
    }
}
