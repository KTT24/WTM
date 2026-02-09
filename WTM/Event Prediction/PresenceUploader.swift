import Foundation

actor PresenceUploadBuffer {
    private var pending: [PresenceSighting] = []
    private var lastSeen: [String: Date] = [:]

    func add(_ sighting: PresenceSighting, dedupeWindow: TimeInterval) -> Bool {
        let key = "\(sighting.observerToken)|\(sighting.seenToken)"
        if let last = lastSeen[key], sighting.seenAt.timeIntervalSince(last) < dedupeWindow {
            return false
        }
        lastSeen[key] = sighting.seenAt
        pending.append(sighting)
        return true
    }

    func drain() -> [PresenceSighting] {
        defer { pending.removeAll() }
        return pending
    }
}

final class PresenceUploader {
    private let api: PresenceAPI
    private let buffer = PresenceUploadBuffer()
    private var timer: Timer?
    private let minRSSI: Int

    init(api: PresenceAPI = PresenceAPI(), minRSSI: Int = EventPredictionConstants.minRSSI) {
        self.api = api
        self.minRSSI = minRSSI
    }

    func start() {
        stop()
        timer = Timer.scheduledTimer(withTimeInterval: EventPredictionConstants.uploadIntervalSeconds, repeats: true) { [weak self] _ in
            self?.flush()
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    func enqueue(_ sighting: PresenceSighting) {
        guard sighting.rssi >= minRSSI else { return }
        Task {
            _ = await buffer.add(sighting, dedupeWindow: EventPredictionConstants.sightingDedupeSeconds)
        }
    }

    private func flush() {
        Task {
            let pending = await buffer.drain()
            guard !pending.isEmpty else { return }
            do {
                try await api.uploadSightings(pending)
            } catch {
                print("Presence upload failed:", error.localizedDescription)
            }
        }
    }
}
