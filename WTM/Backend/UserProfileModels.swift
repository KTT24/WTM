import Foundation

struct UserProfileBars: Decodable {
    let id: UUID
    let visited_bars: [Bars]?
    let nearby_bars: [Bars]?
}

struct UserProfileSeed: Encodable {
    let id: UUID
}

struct UpdateUserBarRequest: Encodable {
    let mode: String
    let bar: Bars
    let distance_m: Double?
}
