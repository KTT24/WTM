import Foundation

final class UserBarService {
    private enum Keys {
        static let profile = "local_user_bar_profile"
    }

    private let defaults: UserDefaults
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func fetchProfileBars() async throws -> UserProfileBars {
        let profile = loadProfile()
        return UserProfileBars(
            id: profile.id,
            visited_bars: profile.visited_bars,
            nearby_bars: profile.nearby_bars
        )
    }

    func updateUserBars(mode: String, bar: Bars, distanceMeters: Double? = nil) async throws {
        _ = distanceMeters
        var profile = loadProfile()

        switch mode {
        case "visit":
            upsert(bar, into: &profile.visited_bars)
            if profile.nearby_bars.contains(where: { $0.id == bar.id }) {
                upsert(bar, into: &profile.nearby_bars)
            }
        case "nearby":
            upsert(bar, into: &profile.nearby_bars)
        default:
            break
        }

        try saveProfile(profile)
    }

    private func loadProfile() -> StoredUserBars {
        guard let data = defaults.data(forKey: Keys.profile),
              let decoded = try? decoder.decode(StoredUserBars.self, from: data) else {
            let empty = StoredUserBars(id: UUID(), visited_bars: [], nearby_bars: [])
            try? saveProfile(empty)
            return empty
        }
        return decoded
    }

    private func saveProfile(_ profile: StoredUserBars) throws {
        let data = try encoder.encode(profile)
        defaults.set(data, forKey: Keys.profile)
    }

    private func upsert(_ bar: Bars, into list: inout [Bars]) {
        if let idx = list.firstIndex(where: { $0.id == bar.id }) {
            list[idx] = bar
        } else {
            list.append(bar)
        }
    }
}

private struct StoredUserBars: Codable {
    let id: UUID
    var visited_bars: [Bars]
    var nearby_bars: [Bars]
}
