import Foundation
import Supabase

final class PartySuggestionService {
    func fetchPendingSuggestion() async throws -> PartySuggestion? {
        let suggestions: [PartySuggestion] = try await supabase
            .from("party_suggestions")
            .select()
            .eq("status", value: PartySuggestionStatus.pending.rawValue)
            .order("suggested_at", ascending: true)
            .limit(1)
            .execute()
            .value
        return suggestions.first
    }

    func updateStatus(id: UUID, status: PartySuggestionStatus) async throws {
        let payload = PartySuggestionStatusUpdate(status: status, respondedAt: Date())
        try await supabase
            .from("party_suggestions")
            .update(payload)
            .eq("id", value: id)
            .execute()
    }
}
