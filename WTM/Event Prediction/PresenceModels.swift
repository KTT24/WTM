import Foundation

struct PresenceToken: Equatable {
    let value: String
    let expiresAt: Date
}

struct PresenceSighting: Hashable {
    let observerToken: String
    let seenToken: String
    let rssi: Int
    let seenAt: Date
}

struct PresenceTokenRegistration: Encodable {
    let token: String
    let expiresAt: Date

    enum CodingKeys: String, CodingKey {
        case token
        case expiresAt = "expires_at"
    }
}

struct PresenceSightingUpload: Encodable {
    let observerToken: String
    let seenToken: String
    let rssi: Int
    let seenAt: Date

    enum CodingKeys: String, CodingKey {
        case observerToken = "observer_token"
        case seenToken = "seen_token"
        case rssi
        case seenAt = "seen_at"
    }
}
