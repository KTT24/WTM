import Foundation

enum PartySuggestionStatus: String, Codable {
    case pending
    case accepted
    case dismissed
    case privateParty = "private_party"
}

struct PartySuggestion: Identifiable, Codable {
    let id: UUID
    let groupId: UUID
    let participantCount: Int
    let suggestedAt: Date
    var status: PartySuggestionStatus

    enum CodingKeys: String, CodingKey {
        case id
        case groupId = "group_id"
        case participantCount = "participant_count"
        case suggestedAt = "suggested_at"
        case status
    }
}

struct PartySuggestionStatusUpdate: Encodable {
    let status: PartySuggestionStatus
    let respondedAt: Date

    enum CodingKeys: String, CodingKey {
        case status
        case respondedAt = "responded_at"
    }
}
