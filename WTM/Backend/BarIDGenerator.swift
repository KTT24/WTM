import Foundation
import CryptoKit

enum BarIDGenerator {
    static func deterministicUUID(name: String, latitude: Double, longitude: Double) -> UUID {
        let input = "\(name.lowercased())|\(latitude)|\(longitude)"
        let hash = SHA256.hash(data: Data(input.utf8))
        let bytes = Array(hash)
        let uuidBytes: uuid_t = (
            bytes[0], bytes[1], bytes[2], bytes[3],
            bytes[4], bytes[5], bytes[6], bytes[7],
            bytes[8], bytes[9], bytes[10], bytes[11],
            bytes[12], bytes[13], bytes[14], bytes[15]
        )
        return UUID(uuid: uuidBytes)
    }
}
