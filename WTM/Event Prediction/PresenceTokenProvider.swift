import Foundation
import CryptoKit
import Security

final class PresenceTokenProvider {
    private let seedStore: PresenceSeedStore
    private let rotationSeconds: TimeInterval
    private let tokenByteLength: Int

    init(
        seedStore: PresenceSeedStore = .shared,
        rotationSeconds: TimeInterval = EventPredictionConstants.tokenRotationSeconds,
        tokenByteLength: Int = EventPredictionConstants.tokenByteLength
    ) {
        self.seedStore = seedStore
        self.rotationSeconds = rotationSeconds
        self.tokenByteLength = tokenByteLength
    }

    func currentToken(date: Date = Date()) -> PresenceToken {
        let window = Int(date.timeIntervalSince1970 / rotationSeconds)
        let seed = seedStore.currentSeed()
        let tokenData = tokenBytes(for: window, seed: seed)
        let tokenString = tokenData.map { String(format: "%02x", $0) }.joined()
        let expiresAt = Date(timeIntervalSince1970: Double(window + 1) * rotationSeconds)
        return PresenceToken(value: tokenString, expiresAt: expiresAt)
    }

    func currentTokenData(date: Date = Date()) -> Data {
        let window = Int(date.timeIntervalSince1970 / rotationSeconds)
        let seed = seedStore.currentSeed()
        return tokenBytes(for: window, seed: seed)
    }

    private func tokenBytes(for window: Int, seed: Data) -> Data {
        var bigEndian = window.bigEndian
        let windowData = Data(bytes: &bigEndian, count: MemoryLayout<Int>.size)
        let key = SymmetricKey(data: seed)
        let hmac = HMAC<SHA256>.authenticationCode(for: windowData, using: key)
        let full = Data(hmac)
        if full.count <= tokenByteLength {
            return full
        }
        return full.prefix(tokenByteLength)
    }
}

final class PresenceSeedStore {
    static let shared = PresenceSeedStore()

    private let defaults: UserDefaults
    private let seedKey = "event_prediction_seed"
    private let createdAtKey = "event_prediction_seed_created_at"

    private init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func currentSeed() -> Data {
        if let stored = storedSeed(), !isExpired(createdAt: stored.createdAt) {
            return stored.seed
        }

        let seed = generateSeed()
        defaults.set(seed.base64EncodedString(), forKey: seedKey)
        defaults.set(Date().timeIntervalSince1970, forKey: createdAtKey)
        return seed
    }

    private func storedSeed() -> (seed: Data, createdAt: Date)? {
        guard let base64 = defaults.string(forKey: seedKey),
              let data = Data(base64Encoded: base64) else {
            return nil
        }

        let createdAtTimestamp = defaults.double(forKey: createdAtKey)
        let createdAt = createdAtTimestamp > 0 ? Date(timeIntervalSince1970: createdAtTimestamp) : .distantPast
        return (data, createdAt)
    }

    private func isExpired(createdAt: Date) -> Bool {
        let rotation = EventPredictionConstants.tokenSeedRotationHours * 3600
        return Date().timeIntervalSince(createdAt) > rotation
    }

    private func generateSeed() -> Data {
        var bytes = [UInt8](repeating: 0, count: 32)
        _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        return Data(bytes)
    }
}
