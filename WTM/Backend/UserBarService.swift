import Foundation
import Supabase

final class UserBarService {
    func fetchProfileBars() async throws -> UserProfileBars {
        let session = try await supabase.auth.session
        let userId = session.user.id

        let profile: UserProfileBars = try await supabase
            .from("profiles")
            .upsert(UserProfileSeed(id: userId), onConflict: "id")
            .select()
            .single()
            .execute()
            .value

        return profile
    }

    func updateUserBars(mode: String, bar: Bars, distanceMeters: Double? = nil) async throws {
        let payload = UpdateUserBarRequest(mode: mode, bar: bar, distance_m: distanceMeters)
        try await supabase.functions.invoke(
            "update_user_bars",
            options: FunctionInvokeOptions(method: .post, body: payload)
        )
    }
}
