//
//  AppDataStore.swift
//  WTM
//

import Foundation
import Supabase
import Combine

@MainActor
final class AppDataStore: ObservableObject {
    @Published private(set) var nearbyBars: [Bars] = []
    @Published private(set) var visitedBars: [Bars] = []
    @Published private(set) var localBars: [LocalBar] = []
    @Published private(set) var events: [Event] = []
    @Published private(set) var goingEventIDs: Set<Int>
    @Published private(set) var weeklyLeaderboard: [EventLeaderboardEntry] = []
    @Published private(set) var monthlyLeaderboard: [EventLeaderboardEntry] = []

    @Published private(set) var isLoadingBars = false
    @Published private(set) var isLoadingEvents = false
    @Published private(set) var isLoadingLeaderboard = false

    @Published private(set) var barsError: String?
    @Published private(set) var eventsError: String?
    @Published private(set) var leaderboardError: String?

    private let userBarService = UserBarService()
    private let eventLeaderboardService = EventLeaderboardService()
    private let notificationManager = NotificationManager.shared
    private let defaults: UserDefaults
    private let cacheTTL: TimeInterval = 120
    private var lastBarsFetch: Date?
    private var lastEventsFetch: Date?
    private var lastLeaderboardFetch: Date?
    private static let goingEventsKey = "going_event_ids"
    private static let notificationsEnabledKey = "enableNotifications"
    private static let weekendPromptsEnabledKey = "enableWeekendPromptsNotifications"
    private static let newEventsEnabledKey = "enableNewEventNotifications"
    private static let eventChatsEnabledKey = "enableEventChatNotifications"

    private static let localDateParser: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone.current
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    private static let localTimeParser: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone.current
        formatter.dateFormat = "HH:mm:ss"
        return formatter
    }()

    var liveEvents: [Event] {
        let now = Date()
        return events.filter { isEventLive($0, now: now) }
    }

    var goingEvents: [Event] {
        events.filter { goingEventIDs.contains($0.id) }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let rawIDs = defaults.array(forKey: Self.goingEventsKey) as? [Int] ?? []
        self.goingEventIDs = Set(rawIDs)
    }

    func preloadIfNeeded() async {
        async let _ = loadBars()
        async let _ = loadEvents()
        async let _ = loadLeaderboards()
        _ = await ()
    }

    func clearBars() {
        nearbyBars.removeAll()
        visitedBars.removeAll()
        localBars.removeAll()
        barsError = nil
        lastBarsFetch = nil
    }

    func clearEvents() {
        events.removeAll()
        eventsError = nil
        leaderboardError = nil
        weeklyLeaderboard.removeAll()
        monthlyLeaderboard.removeAll()
        lastEventsFetch = nil
        lastLeaderboardFetch = nil
    }

    func isGoing(to event: Event) -> Bool {
        goingEventIDs.contains(event.id)
    }

    func toggleGoing(for event: Event) {
        let isNowGoing: Bool
        if goingEventIDs.contains(event.id) {
            goingEventIDs.remove(event.id)
            isNowGoing = false
        } else {
            goingEventIDs.insert(event.id)
            isNowGoing = true
        }
        persistGoingEventIDs()

        Task {
            await notificationManager.scheduleGoingStateNotification(
                for: event,
                isGoing: isNowGoing,
                preferences: notificationPreferences
            )
            await loadLeaderboards(force: true)
        }
    }

    func loadBars(force: Bool = false) async {
        if !force,
           let lastBarsFetch,
           (!nearbyBars.isEmpty || !visitedBars.isEmpty),
           Date().timeIntervalSince(lastBarsFetch) < cacheTTL {
            return
        }

        guard !isLoadingBars else { return }

        isLoadingBars = true
        defer { isLoadingBars = false }

        do {
            let profile = try await userBarService.fetchProfileBars()
            nearbyBars = profile.nearby_bars ?? []
            visitedBars = profile.visited_bars ?? []
            barsError = nil
            lastBarsFetch = Date()
        } catch {
            barsError = "Failed to load bars: \(error.localizedDescription)"
        }
    }

    func recordVisit(for bar: Bars) async throws {
        try await userBarService.updateUserBars(mode: "visit", bar: bar)
        merge(bar, into: &visitedBars)
        if nearbyBars.contains(where: { $0.id == bar.id }) {
            merge(bar, into: &nearbyBars)
        }
    }

    func recordNearby(_ bar: Bars, distanceMeters: Double? = nil) async throws {
        try await userBarService.updateUserBars(mode: "nearby", bar: bar, distanceMeters: distanceMeters)
        merge(bar, into: &nearbyBars)
    }

    func updateLocalBars(_ bars: [LocalBar]) {
        localBars = bars
    }

    func loadEvents(force: Bool = false) async {
        if !force,
           let lastEventsFetch,
           !events.isEmpty,
           Date().timeIntervalSince(lastEventsFetch) < cacheTTL {
            return
        }

        guard !isLoadingEvents else { return }

        isLoadingEvents = true
        defer { isLoadingEvents = false }

        do {
            let fetched: [Event] = try await supabase
                .from("events")
                .select()
                .order("date", ascending: true)
                .execute()
                .value

            let now = Date()
            var expiredIds: [Int] = []
            let active = fetched.filter { event in
                if isEventExpired(event, now: now) {
                    expiredIds.append(event.id)
                    return false
                }
                return true
            }

            events = active
            eventsError = nil
            lastEventsFetch = Date()

            if !expiredIds.isEmpty {
                let beforeCount = goingEventIDs.count
                goingEventIDs.subtract(expiredIds)
                if goingEventIDs.count != beforeCount {
                    persistGoingEventIDs()
                }
            }

            await loadLeaderboards()

            await notificationManager.notifyForNewEventsIfNeeded(
                currentEvents: active,
                preferences: notificationPreferences
            )

            await notificationManager.syncScheduledNotifications(
                preferences: notificationPreferences,
                goingEvents: goingEvents
            )

            if !expiredIds.isEmpty {
                try await deleteExpiredEvents(expiredIds)
            }
        } catch {
            eventsError = "Failed to load events: \(error.localizedDescription)"
        }
    }

    func loadLeaderboards(force: Bool = false) async {
        if !force,
           let lastLeaderboardFetch,
           (!weeklyLeaderboard.isEmpty || !monthlyLeaderboard.isEmpty),
           Date().timeIntervalSince(lastLeaderboardFetch) < cacheTTL {
            return
        }

        guard !isLoadingLeaderboard else { return }

        isLoadingLeaderboard = true
        defer { isLoadingLeaderboard = false }

        do {
            async let weekly = eventLeaderboardService.fetchLeaderboard(for: .week, limit: 10)
            async let monthly = eventLeaderboardService.fetchLeaderboard(for: .month, limit: 10)
            let (weeklyResults, monthlyResults) = try await (weekly, monthly)
            weeklyLeaderboard = weeklyResults
            monthlyLeaderboard = monthlyResults
            leaderboardError = nil
            lastLeaderboardFetch = Date()
        } catch {
            leaderboardError = "Failed to load leaderboard: \(error.localizedDescription)"
        }
    }

    private func isEventExpired(_ event: Event, now: Date) -> Bool {
        guard let eventDate = AppDataStore.localDateParser.date(from: event.date) else {
            return false
        }

        let calendar = Calendar.current
        if calendar.isDate(eventDate, inSameDayAs: now) {
            guard let endTime = event.end_time,
                  let endTimeDate = AppDataStore.localTimeParser.date(from: endTime) else {
                return false
            }

            let timeComponents = calendar.dateComponents([.hour, .minute, .second], from: endTimeDate)
            var dateComponents = calendar.dateComponents([.year, .month, .day], from: eventDate)
            dateComponents.hour = timeComponents.hour
            dateComponents.minute = timeComponents.minute
            dateComponents.second = timeComponents.second

            guard let endDateTime = calendar.date(from: dateComponents) else {
                return false
            }

            return now > endDateTime.addingTimeInterval(60)
        }

        return eventDate < calendar.startOfDay(for: now)
    }

    private func isEventLive(_ event: Event, now: Date) -> Bool {
        guard let eventDate = AppDataStore.localDateParser.date(from: event.date) else {
            return false
        }

        let calendar = Calendar.current
        guard calendar.isDate(eventDate, inSameDayAs: now) else {
            return false
        }

        if let startTime = event.start_time,
           let startDateTime = dateTime(for: eventDate, time: startTime),
           now < startDateTime {
            return false
        }

        if let endTime = event.end_time,
           let endDateTime = dateTime(for: eventDate, time: endTime),
           now > endDateTime {
            return false
        }

        return true
    }

    private func dateTime(for date: Date, time: String) -> Date? {
        guard let timeDate = AppDataStore.localTimeParser.date(from: time) else {
            return nil
        }

        let calendar = Calendar.current
        let timeComponents = calendar.dateComponents([.hour, .minute, .second], from: timeDate)
        var dateComponents = calendar.dateComponents([.year, .month, .day], from: date)
        dateComponents.hour = timeComponents.hour
        dateComponents.minute = timeComponents.minute
        dateComponents.second = timeComponents.second
        return calendar.date(from: dateComponents)
    }

    private func deleteExpiredEvents(_ ids: [Int]) async throws {
        for id in ids {
            _ = try await supabase
                .from("events")
                .delete()
                .eq("id", value: id)
                .execute()
        }
    }

    private func merge(_ bar: Bars, into list: inout [Bars]) {
        if let index = list.firstIndex(where: { $0.id == bar.id }) {
            list[index] = bar
        } else {
            list.append(bar)
        }
    }

    private func persistGoingEventIDs() {
        defaults.set(Array(goingEventIDs), forKey: Self.goingEventsKey)
    }

    private var notificationPreferences: NotificationPreferences {
        NotificationPreferences(
            masterEnabled: boolValue(forKey: Self.notificationsEnabledKey, defaultValue: true),
            weekendPromptsEnabled: boolValue(forKey: Self.weekendPromptsEnabledKey, defaultValue: true),
            newEventsEnabled: boolValue(forKey: Self.newEventsEnabledKey, defaultValue: true),
            eventChatsEnabled: boolValue(forKey: Self.eventChatsEnabledKey, defaultValue: true)
        )
    }

    private func boolValue(forKey key: String, defaultValue: Bool) -> Bool {
        guard defaults.object(forKey: key) != nil else { return defaultValue }
        return defaults.bool(forKey: key)
    }

    func insertFakeEvents(count: Int) async {
        guard count > 0 else { return }

        let now = Date()
        var inserts: [EventInsert] = []
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"

        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "HH:mm:ss"

        for index in 0..<count {
            let date = Calendar.current.date(byAdding: .day, value: index, to: now) ?? now
            let start = Calendar.current.date(byAdding: .hour, value: 20, to: date) ?? date
            let end = Calendar.current.date(byAdding: .hour, value: 23, to: date) ?? date

            inserts.append(EventInsert(
                name: "Debug Party \(index + 1)",
                date: formatter.string(from: date),
                start_time: timeFormatter.string(from: start),
                end_time: timeFormatter.string(from: end),
                location: "Near You",
                description: "Auto-generated debug party."
            ))
        }

        do {
            _ = try await supabase
                .from("events")
                .insert(inserts)
                .execute()
            await loadEvents(force: true)
        } catch {
            eventsError = "Failed to add fake parties: \(error.localizedDescription)"
        }
    }
}

private struct EventInsert: Encodable {
    let name: String
    let date: String
    let start_time: String
    let end_time: String
    let location: String
    let description: String
}

enum LeaderboardWindow: String, CaseIterable, Identifiable {
    case week
    case month

    var id: String { rawValue }

    var title: String {
        switch self {
        case .week:
            return "Week"
        case .month:
            return "Month"
        }
    }

    var subtitle: String {
        switch self {
        case .week:
            return "Last 7 days"
        case .month:
            return "Last 30 days"
        }
    }
}

struct EventLeaderboardEntry: Identifiable, Equatable {
    let username: String
    let rank: Int
    let numOfBars: Int

    var id: String {
        "\(rank)-\(username.lowercased())-\(numOfBars)"
    }

    var eventCount: Int { numOfBars }
}

private final class EventLeaderboardService {
    func fetchLeaderboard(for window: LeaderboardWindow, limit: Int) async throws -> [EventLeaderboardEntry] {
        let tableName = tableName(for: window)
        let rows: [StoredLeaderboardRow] = try await supabase
            .from(tableName)
            .select("username, rank, num_of_bars")
            .order("rank", ascending: true)
            .limit(limit)
            .execute()
            .value

        return rows.map {
            EventLeaderboardEntry(
                username: normalizedUsername($0.username),
                rank: max($0.rank, 1),
                numOfBars: max($0.num_of_bars, 0)
            )
        }
    }

    private func tableName(for window: LeaderboardWindow) -> String {
        switch window {
        case .week:
            return "leaderboard_week"
        case .month:
            return "leaderboard_month"
        }
    }

    private func normalizedUsername(_ value: String?) -> String {
        let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? "Someone" : trimmed
    }
}

private struct StoredLeaderboardRow: Decodable {
    let username: String?
    let rank: Int
    let num_of_bars: Int
}
