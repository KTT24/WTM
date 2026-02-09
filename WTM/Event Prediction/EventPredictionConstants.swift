import Foundation
import CoreBluetooth

enum EventPredictionConstants {
    static let serviceUUID = CBUUID(string: "A8A37B7C-9A4D-4E2E-90B8-4D4F8F4C2B1D")

    static let tokenRotationSeconds: TimeInterval = 120
    static let tokenSeedRotationHours: TimeInterval = 24
    static let tokenByteLength = 8

    static let minRSSI = -70
    static let sightingDedupeSeconds: TimeInterval = 12
    static let uploadIntervalSeconds: TimeInterval = 20

    static let suggestionPollSeconds: TimeInterval = 60
    static let suggestionCooldownSeconds: TimeInterval = 4 * 60 * 60
}
