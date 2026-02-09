import Foundation
import Supabase

final class PresenceAPI {
    func registerToken(_ token: PresenceToken) async throws {
        let payload = PresenceTokenRegistration(token: token.value, expiresAt: token.expiresAt)
        try await supabase
            .from("presence_tokens")
            .upsert(payload, onConflict: "token")
            .execute()
    }

    func uploadSightings(_ sightings: [PresenceSighting]) async throws {
        guard !sightings.isEmpty else { return }
        let payloads = sightings.map {
            PresenceSightingUpload(
                observerToken: $0.observerToken,
                seenToken: $0.seenToken,
                rssi: $0.rssi,
                seenAt: $0.seenAt
            )
        }

        try await supabase
            .from("presence_sightings")
            .insert(payloads)
            .execute()
    }
}
