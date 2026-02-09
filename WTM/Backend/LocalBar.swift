import Foundation
import MapKit

struct LocalBar: Identifiable, Hashable {
    let id: UUID
    let name: String
    let coordinate: CLLocationCoordinate2D
    let address: String

    init(
        id: UUID = UUID(),
        name: String,
        coordinate: CLLocationCoordinate2D,
        address: String
    ) {
        self.id = id
        self.name = name
        self.coordinate = coordinate
        self.address = address
    }
}
extension LocalBar {
    static func == (lhs: LocalBar, rhs: LocalBar) -> Bool {
        return lhs.id == rhs.id &&
            lhs.name == rhs.name &&
            lhs.coordinate.latitude == rhs.coordinate.latitude &&
            lhs.coordinate.longitude == rhs.coordinate.longitude &&
            lhs.address == rhs.address
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(name)
        hasher.combine(coordinate.latitude)
        hasher.combine(coordinate.longitude)
        hasher.combine(address)
    }
}
