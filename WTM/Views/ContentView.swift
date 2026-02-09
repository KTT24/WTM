//
//  MainTabView.swift
//  WTM
//

import SwiftUI
import Supabase
import MapKit

struct ContentView: View {
    enum Tab: String, CaseIterable {
        case map
        case upcoming
        case add
        case chats
        case account
    }

    @AppStorage("defaultPrimaryTab") private var defaultPrimaryTabRaw: String = Tab.map.rawValue
    @State private var selectedTab: Tab
    @State private var showAddEvent = false

    init() {
        let saved = UserDefaults.standard.string(forKey: "defaultPrimaryTab") ?? Tab.map.rawValue
        _selectedTab = State(initialValue: Tab(rawValue: saved) ?? .map)
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            Group {
                switch selectedTab {
                case .map:
                    BarsMapView()
                case .upcoming:
                    UpcomingEventsView()
                case .add:
                    BarsMapView()
                case .chats:
                    ChatsView()
                case .account:
                    AccountView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            CustomTabBar(
                selectedTab: $selectedTab,
                addAction: { showAddEvent = true }
            )
        }
        .fullScreenCover(isPresented: $showAddEvent) {
            AddEventView()
        }
        .onChange(of: defaultPrimaryTabRaw) { raw in
            guard let tab = Tab(rawValue: raw), selectedTab != .add else { return }
            selectedTab = tab
        }
    }
}

private struct CustomTabBar: View {
    @Binding var selectedTab: ContentView.Tab
    let addAction: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            tabButton(icon: "map.fill", title: "Map", tab: .map)
            tabButton(icon: "calendar", title: "Events", tab: .upcoming)
            addButton
            tabButton(icon: "bubble.left.and.bubble.right.fill", title: "Chats", tab: .chats)
            tabButton(icon: "person.fill", title: "Me", tab: .account)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 16)
        .background(.ultraThinMaterial)
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.white.opacity(0.32), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .shadow(color: .black.opacity(0.16), radius: 14, x: 0, y: 8)
        .padding(.horizontal, 14)
        .padding(.bottom, 8)
    }

    private var addButton: some View {
        Button(action: addAction) {
            VStack(spacing: 2) {
                Image(systemName: "plus")
                    .font(.system(size: 24, weight: .black))
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 60)
            .background(
                LinearGradient(
                    colors: [Color(red: 0.22, green: 0.72, blue: 1.0), Color(red: 0.20, green: 0.42, blue: 1.0)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.white.opacity(0.58), lineWidth: 1.2)
            )
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .shadow(color: Color.blue.opacity(0.35), radius: 12, x: 0, y: 6)
            .scaleEffect(1.03)
        }
        .buttonStyle(.plain)
    }

    private func tabButton(icon: String, title: String, tab: ContentView.Tab) -> some View {
        let isSelected = selectedTab == tab
        return Button {
            selectedTab = tab
        } label: {
            VStack(spacing: 2) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                Text(title)
                    .font(.system(size: 11, weight: .semibold))
            }
            .foregroundStyle(isSelected ? .white : .white.opacity(0.72))
            .frame(maxWidth: .infinity)
            .frame(height: 56)
        }
        .buttonStyle(.plain)
    }
}

private struct UpcomingEventsView: View {
    @EnvironmentObject private var dataStore: AppDataStore
    @State private var selectedEvent: Event?
    @State private var showAddEvent = false
    @State private var leaderboardWindow: LeaderboardWindow = .week

    private var grouped: EventGrouping {
        EventGrouping(events: dataStore.events)
    }

    private var totalEvents: Int {
        grouped.activeNow.count + grouped.upcoming.count
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AnimatedMeshBackground()
                    .blur(radius: 30)
                    .ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 14) {
                        EventsSummaryCard(
                            activeCount: grouped.activeNow.count,
                            upcomingCount: grouped.upcoming.count,
                            totalCount: totalEvents
                        )
                        EventsLeaderboardCard(
                            weeklyEntries: dataStore.weeklyLeaderboard,
                            monthlyEntries: dataStore.monthlyLeaderboard,
                            selectedWindow: $leaderboardWindow,
                            isLoading: dataStore.isLoadingLeaderboard,
                            errorMessage: dataStore.leaderboardError
                        )

                        if dataStore.isLoadingEvents && dataStore.events.isEmpty {
                            EventsGlassCard {
                                HStack(spacing: 10) {
                                    ProgressView()
                                    Text("Loading events...")
                                        .font(.subheadline)
                                        .foregroundStyle(.white.opacity(0.8))
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        } else if totalEvents == 0 {
                            EventsGlassCard {
                                VStack(spacing: 10) {
                                    Image(systemName: "calendar.badge.clock")
                                        .font(.system(size: 34))
                                        .foregroundStyle(.white.opacity(0.85))
                                    Text("No Upcoming Events")
                                        .font(.headline.weight(.semibold))
                                        .foregroundStyle(.white)
                                    Text("Check back soon or start a party so people can join.")
                                        .font(.caption)
                                        .foregroundStyle(.white.opacity(0.7))
                                        .multilineTextAlignment(.center)

                                    Button {
                                        showAddEvent = true
                                    } label: {
                                        Text("Start a Party")
                                            .font(.subheadline.weight(.semibold))
                                            .foregroundStyle(.white)
                                            .frame(maxWidth: .infinity)
                                            .padding(.vertical, 10)
                                            .background(.white.opacity(0.14), in: RoundedRectangle(cornerRadius: 11, style: .continuous))
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 11, style: .continuous)
                                                    .stroke(.white.opacity(0.22), lineWidth: 1)
                                            )
                                    }
                                    .buttonStyle(.plain)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 6)
                            }
                        } else {
                            if !grouped.activeNow.isEmpty {
                                EventsSectionHeader(
                                    title: "Active Now",
                                    subtitle: "Happening right now"
                                )

                                ForEach(grouped.activeNow) { event in
                                    EventRow(
                                        event: event,
                                        isGoing: dataStore.isGoing(to: event),
                                        isLive: true,
                                        onGoingTap: { dataStore.toggleGoing(for: event) },
                                        onDetailsTap: { selectedEvent = event }
                                    )
                                }
                            }

                            if !grouped.upcoming.isEmpty {
                                EventsSectionHeader(
                                    title: "Coming Up",
                                    subtitle: "Plan ahead and join early"
                                )

                                ForEach(grouped.upcoming) { event in
                                    EventRow(
                                        event: event,
                                        isGoing: dataStore.isGoing(to: event),
                                        isLive: false,
                                        onGoingTap: { dataStore.toggleGoing(for: event) },
                                        onDetailsTap: { selectedEvent = event }
                                    )
                                }
                            }
                        }

                        if let errorMessage = dataStore.eventsError {
                            EventsGlassCard {
                                Text(errorMessage)
                                    .font(.caption)
                                    .foregroundStyle(.red.opacity(0.95))
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 18)
                    .padding(.bottom, 96)
                }
                .refreshable {
                    async let _ = dataStore.loadEvents(force: true)
                    async let _ = dataStore.loadLeaderboards(force: true)
                    _ = await ()
                }
            }
            .navigationTitle("Events")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showAddEvent = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                    }
                }
            }
            .task {
                async let _ = dataStore.loadEvents()
                async let _ = dataStore.loadLeaderboards()
                _ = await ()
            }
            .sheet(item: $selectedEvent) { event in
                EventDetailSheet(event: event)
            }
            .fullScreenCover(isPresented: $showAddEvent) {
                AddEventView()
            }
        }
    }
}

private struct EventsSummaryCard: View {
    let activeCount: Int
    let upcomingCount: Int
    let totalCount: Int

    var body: some View {
        EventsGlassCard {
            VStack(alignment: .leading, spacing: 10) {
                Text("Tonight's Plan")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.95))

                HStack(spacing: 10) {
                    EventSummaryPill(title: "Live", value: "\(activeCount)", tint: .orange)
                    EventSummaryPill(title: "Later", value: "\(upcomingCount)", tint: .cyan)
                    EventSummaryPill(title: "Total", value: "\(totalCount)", tint: .white)
                }
            }
        }
    }
}

private struct EventsLeaderboardCard: View {
    let weeklyEntries: [EventLeaderboardEntry]
    let monthlyEntries: [EventLeaderboardEntry]
    @Binding var selectedWindow: LeaderboardWindow
    let isLoading: Bool
    let errorMessage: String?

    private var entries: [EventLeaderboardEntry] {
        switch selectedWindow {
        case .week:
            return weeklyEntries
        case .month:
            return monthlyEntries
        }
    }

    var body: some View {
        EventsGlassCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Leaderboard")
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.95))
                        Text(selectedWindow.subtitle)
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.68))
                    }

                    Spacer()

                    windowSelector
                }

                if isLoading && entries.isEmpty {
                    HStack(spacing: 8) {
                        ProgressView()
                        Text("Loading leaderboard...")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.75))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                } else if entries.isEmpty {
                    Text("No attendance yet for this period.")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.75))
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    VStack(spacing: 8) {
                        ForEach(entries) { entry in
                            LeaderboardRow(rank: entry.rank, entry: entry)
                        }
                    }
                }

                if let errorMessage {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundStyle(.red.opacity(0.95))
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }

    private var windowSelector: some View {
        HStack(spacing: 6) {
            ForEach(LeaderboardWindow.allCases) { window in
                Button {
                    selectedWindow = window
                } label: {
                    Text(window.title)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(selectedWindow == window ? .white : .white.opacity(0.72))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(
                            (selectedWindow == window ? Color.white.opacity(0.18) : Color.white.opacity(0.08)),
                            in: Capsule()
                        )
                        .overlay(
                            Capsule()
                                .stroke(.white.opacity(0.2), lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
            }
        }
    }
}

private struct LeaderboardRow: View {
    let rank: Int
    let entry: EventLeaderboardEntry

    private var rankTint: Color {
        switch rank {
        case 1:
            return .yellow
        case 2:
            return .gray
        case 3:
            return .orange
        default:
            return .cyan
        }
    }

    var body: some View {
        HStack(spacing: 10) {
            Text("\(rank)")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(.white)
                .frame(width: 26, height: 26)
                .background(rankTint.opacity(0.38), in: Circle())

            Text(entry.username)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)
                .lineLimit(1)

            Spacer()

            Text("\(entry.numOfBars) \(entry.numOfBars == 1 ? "bar" : "bars")")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white.opacity(0.78))
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 9)
        .background(.white.opacity(0.1), in: RoundedRectangle(cornerRadius: 11, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .stroke(.white.opacity(0.2), lineWidth: 1)
        )
    }
}

private struct EventSummaryPill: View {
    let title: String
    let value: String
    let tint: Color

    var body: some View {
        VStack(spacing: 3) {
            Text(value)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(.white)
            Text(title)
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.72))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(tint.opacity(0.18), in: RoundedRectangle(cornerRadius: 11, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .stroke(.white.opacity(0.2), lineWidth: 1)
        )
    }
}

private struct EventsSectionHeader: View {
    let title: String
    let subtitle: String

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.96))
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.68))
            }
            Spacer()
        }
        .padding(.top, 2)
    }
}

private struct EventsGlassCard<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            content
        }
        .padding(14)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(.white.opacity(0.22), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.22), radius: 12, x: 0, y: 6)
    }
}

private struct ChatsView: View {
    @EnvironmentObject private var dataStore: AppDataStore
    @AppStorage("pinnedChatThreadIDs") private var pinnedChatThreadIDsRaw: String = ""
    @State private var selectedChat: ChatThread?
    @StateObject private var locationManager = LocationManager()

    private var closestLocalBars: [LocalBar] {
        let bars = dataStore.localBars
        guard !bars.isEmpty else { return [] }
        guard let location = locationManager.effectiveLocation else {
            return Array(bars.prefix(5))
        }

        return bars
            .map { bar in
                let barLocation = CLLocation(latitude: bar.coordinate.latitude, longitude: bar.coordinate.longitude)
                let distance = barLocation.distance(from: location)
                return (bar, distance)
            }
            .sorted { $0.1 < $1.1 }
            .prefix(5)
            .map { $0.0 }
    }

    private var sortedVisitedBars: [Bars] {
        dataStore.visitedBars.sorted {
            $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
    }

    private var pinnedThreadIDs: Set<String> {
        Set(
            pinnedChatThreadIDsRaw
                .split(separator: ",")
                .map { String($0) }
        )
    }

    private var eventThreads: [ChatThread] {
        dataStore.goingEvents.map {
            ChatThread.event(id: $0.id, title: $0.name, subtitle: $0.location)
        }
    }

    private var closestBarThreads: [ChatThread] {
        closestLocalBars.map { bar in
            ChatThread.bar(
                id: BarIDGenerator.deterministicUUID(
                    name: bar.name,
                    latitude: bar.coordinate.latitude,
                    longitude: bar.coordinate.longitude
                ),
                title: bar.name,
                subtitle: bar.address
            )
        }
    }

    private var visitedBarThreads: [ChatThread] {
        sortedVisitedBars.map { bar in
            ChatThread.bar(id: bar.id, title: bar.name, subtitle: bar.address)
        }
    }

    private var allUniqueThreads: [ChatThread] {
        dedupeThreads(eventThreads + closestBarThreads + visitedBarThreads)
    }

    private var pinnedThreads: [ChatThread] {
        allUniqueThreads
            .filter { pinnedThreadIDs.contains($0.id) }
            .sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
    }

    private var unpinnedEventThreads: [ChatThread] {
        eventThreads.filter { !pinnedThreadIDs.contains($0.id) }
    }

    private var unpinnedClosestBarThreads: [ChatThread] {
        closestBarThreads.filter { !pinnedThreadIDs.contains($0.id) }
    }

    private var unpinnedVisitedBarThreads: [ChatThread] {
        visitedBarThreads.filter { !pinnedThreadIDs.contains($0.id) }
    }

    private func dedupeThreads(_ threads: [ChatThread]) -> [ChatThread] {
        var seen = Set<String>()
        var result: [ChatThread] = []
        for thread in threads {
            if seen.insert(thread.id).inserted {
                result.append(thread)
            }
        }
        return result
    }

    private func togglePin(_ thread: ChatThread) {
        var ids = pinnedThreadIDs
        if ids.contains(thread.id) {
            ids.remove(thread.id)
        } else {
            ids.insert(thread.id)
        }
        pinnedChatThreadIDsRaw = ids.sorted().joined(separator: ",")
    }

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: [Color(red: 0.08, green: 0.12, blue: 0.2), Color(red: 0.11, green: 0.18, blue: 0.28)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 14) {
                        EventsGlassCard {
                            VStack(alignment: .leading, spacing: 10) {
                                Text("Conversations")
                                    .font(.headline.weight(.semibold))
                                    .foregroundStyle(.white.opacity(0.95))

                                HStack(spacing: 10) {
                                    EventSummaryPill(title: "Event", value: "\(dataStore.goingEvents.count)", tint: .orange)
                                    EventSummaryPill(title: "Nearby", value: "\(closestLocalBars.count)", tint: .cyan)
                                    EventSummaryPill(title: "Saved", value: "\(sortedVisitedBars.count)", tint: .white)
                                }
                            }
                        }

                        if (dataStore.isLoadingBars || dataStore.isLoadingEvents) && dataStore.nearbyBars.isEmpty && dataStore.events.isEmpty {
                            EventsGlassCard {
                                HStack(spacing: 10) {
                                    ProgressView()
                                    Text("Loading chats...")
                                        .font(.subheadline)
                                        .foregroundStyle(.white.opacity(0.8))
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        } else if allUniqueThreads.isEmpty {
                            EventsGlassCard {
                                VStack(spacing: 10) {
                                    Image(systemName: "bubble.left.and.bubble.right")
                                        .font(.system(size: 34))
                                        .foregroundStyle(.white.opacity(0.85))
                                    Text("No Chats Yet")
                                        .font(.headline.weight(.semibold))
                                        .foregroundStyle(.white)
                                    Text("Join an event or open a nearby bar to start chatting.")
                                        .font(.caption)
                                        .foregroundStyle(.white.opacity(0.72))
                                        .multilineTextAlignment(.center)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 6)
                            }
                        } else {
                            if !pinnedThreads.isEmpty {
                                ChatSectionHeader(title: "Pinned Chats", subtitle: "Your favorites")
                                ForEach(pinnedThreads) { thread in
                                    ChatThreadCard(
                                        icon: thread.kind == .event ? "bolt.fill" : "wineglass.fill",
                                        tint: thread.kind == .event ? .orange : .blue,
                                        title: thread.title,
                                        subtitle: thread.subtitle,
                                        badge: thread.kind == .event ? "Live" : nil,
                                        isPinned: true,
                                        onTogglePin: { togglePin(thread) },
                                        onTap: { selectedChat = thread }
                                    )
                                }
                            }

                            ChatSectionHeader(title: "Event Chats", subtitle: "Events you are going to")
                            if unpinnedEventThreads.isEmpty {
                                EventsGlassCard {
                                    Text(eventThreads.isEmpty
                                        ? "Tap \"I'm Going\" on an event to add its chat here."
                                        : "All event chats are pinned above.")
                                        .font(.caption)
                                        .foregroundStyle(.white.opacity(0.72))
                                }
                            } else {
                                ForEach(unpinnedEventThreads) { thread in
                                    ChatThreadCard(
                                        icon: "bolt.fill",
                                        tint: .orange,
                                        title: thread.title,
                                        subtitle: thread.subtitle,
                                        badge: "Live",
                                        isPinned: false,
                                        onTogglePin: { togglePin(thread) },
                                        onTap: { selectedChat = thread }
                                    )
                                }
                            }

                            ChatSectionHeader(title: "Closest Bars", subtitle: "Open a room nearby")
                            if unpinnedClosestBarThreads.isEmpty {
                                EventsGlassCard {
                                    Text(closestBarThreads.isEmpty
                                        ? "Turn on location to see the closest bars."
                                        : "All nearby bar chats are pinned above.")
                                        .font(.caption)
                                        .foregroundStyle(.white.opacity(0.72))
                                }
                            } else {
                                ForEach(unpinnedClosestBarThreads) { thread in
                                    ChatThreadCard(
                                        icon: "wineglass.fill",
                                        tint: .blue,
                                        title: thread.title,
                                        subtitle: thread.subtitle,
                                        badge: nil,
                                        isPinned: false,
                                        onTogglePin: { togglePin(thread) },
                                        onTap: { selectedChat = thread }
                                    )
                                }
                            }

                            if !unpinnedVisitedBarThreads.isEmpty {
                                ChatSectionHeader(title: "Visited Bars", subtitle: "Your saved bar chats")
                                ForEach(unpinnedVisitedBarThreads) { thread in
                                    ChatThreadCard(
                                        icon: "wineglass.fill",
                                        tint: .blue,
                                        title: thread.title,
                                        subtitle: thread.subtitle,
                                        badge: nil,
                                        isPinned: false,
                                        onTogglePin: { togglePin(thread) },
                                        onTap: { selectedChat = thread }
                                    )
                                }
                            }
                        }

                        if let errorMessage = dataStore.barsError ?? dataStore.eventsError {
                            EventsGlassCard {
                                Text(errorMessage)
                                    .font(.caption)
                                    .foregroundStyle(.red.opacity(0.95))
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 18)
                    .padding(.bottom, 96)
                }
                .refreshable {
                    async let _ = dataStore.loadBars(force: true)
                    async let _ = dataStore.loadEvents(force: true)
                    _ = await ()
                }
            }
            .navigationTitle("Chats")
            .navigationBarTitleDisplayMode(.inline)
            .task {
                async let _ = dataStore.loadBars()
                async let _ = dataStore.loadEvents()
                _ = await ()
                locationManager.requestAuthorization()
                locationManager.requestLocation()
            }
            .fullScreenCover(item: $selectedChat) { thread in
                ChatRoomView(thread: thread)
            }
        }
    }

}

private struct ChatSectionHeader: View {
    let title: String
    let subtitle: String

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.96))
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.68))
            }
            Spacer()
        }
        .padding(.top, 2)
    }
}

private struct ChatThreadCard: View {
    let icon: String
    let tint: Color
    let title: String
    let subtitle: String
    let badge: String?
    let isPinned: Bool
    let onTogglePin: () -> Void
    let onTap: () -> Void

    var body: some View {
        EventsGlassCard {
            HStack(spacing: 10) {
                Button(action: onTap) {
                    HStack(spacing: 12) {
                        Circle()
                            .fill(tint.opacity(0.24))
                            .frame(width: 40, height: 40)
                            .overlay(
                                Image(systemName: icon)
                                    .foregroundStyle(tint)
                            )

                        VStack(alignment: .leading, spacing: 4) {
                            Text(title)
                                .font(.headline)
                                .foregroundStyle(.white)
                                .lineLimit(1)
                            Text(subtitle)
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.72))
                                .lineLimit(1)
                        }

                        Spacer()

                        if let badge {
                            Text(badge)
                                .font(.caption2.bold())
                                .foregroundStyle(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(tint.opacity(0.85), in: Capsule())
                        }

                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.6))
                    }
                }
                .buttonStyle(.plain)

                Button(action: onTogglePin) {
                    Image(systemName: isPinned ? "pin.fill" : "pin")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(isPinned ? .yellow : .white.opacity(0.75))
                        .frame(width: 30, height: 30)
                        .background(.white.opacity(0.12), in: Circle())
                }
                .buttonStyle(.plain)
            }
        }
    }
}

private struct ChatThread: Identifiable {
    enum Kind { case bar, event }
    let id: String
    let kind: Kind
    let title: String
    let subtitle: String

    static func bar(id: UUID, title: String, subtitle: String) -> ChatThread {
        ChatThread(id: "bar-\(id.uuidString)", kind: .bar, title: title, subtitle: subtitle)
    }

    static func event(id: Int, title: String, subtitle: String) -> ChatThread {
        ChatThread(id: "event-\(id)", kind: .event, title: title, subtitle: subtitle)
    }
}

private struct ChatRoomView: View {
    let thread: ChatThread

    @State private var messageText = ""
    @Environment(\.dismiss) private var dismiss
    @FocusState private var isComposerFocused: Bool
    @State private var showChatInfo = false

    @State private var messages: [ChatMessage] = [
        ChatMessage(user: "Ava", text: "Pulling up in 10. Who’s already there?", isMe: false),
        ChatMessage(user: "You", text: "I’m on the way now.", isMe: true),
        ChatMessage(user: "Miles", text: "Table by the patio is open.", isMe: false),
        ChatMessage(user: "Jules", text: "Let’s do a round of shots when everyone’s here.", isMe: false),
        ChatMessage(user: "You", text: "Bet. I’ll grab a pitcher too.", isMe: true),
        ChatMessage(user: "Nova", text: "ETA 5 min 🚗", isMe: false)
    ]

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.07, green: 0.1, blue: 0.16), Color(red: 0.1, green: 0.14, blue: 0.24)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .overlay(
                RadialGradient(
                    colors: [Color.white.opacity(0.08), Color.clear],
                    center: .topTrailing,
                    startRadius: 20,
                    endRadius: 420
                )
            )
                .ignoresSafeArea()

            VStack(spacing: 0) {
                ChatHeader(
                    thread: thread,
                    onBack: { dismiss() },
                    onInfo: { showChatInfo = true }
                )

                ScrollViewReader { proxy in
                    ScrollView(showsIndicators: false) {
                        LazyVStack(spacing: 14) {
                            ForEach(messages) { message in
                                MessageBubble(message: message)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                        .padding(.bottom, 24)
                    }
                    .onChange(of: messages.count) { _ in scrollToBottom(proxy) }
                    .onAppear { scrollToBottom(proxy) }
                }

                ChatComposer(
                    messageText: $messageText,
                    isFocused: $isComposerFocused
                ) {
                    sendMessage()
                }
            }
        }
        .sheet(isPresented: $showChatInfo) {
            ChatInfoSheet(thread: thread)
        }
    }

    private func sendMessage() {
        let trimmed = messageText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        messages.append(ChatMessage(user: "You", text: trimmed, isMe: true))
        messageText = ""
    }

    private func scrollToBottom(_ proxy: ScrollViewProxy) {
        if let last = messages.last {
            withAnimation(.easeOut(duration: 0.2)) {
                proxy.scrollTo(last.id, anchor: .bottom)
            }
        }
    }
}

private struct MessageBubble: View {
    let message: ChatMessage

    var body: some View {
        HStack(alignment: .bottom, spacing: 10) {
            if message.isMe { Spacer(minLength: 24) }

            if !message.isMe {
                Circle()
                    .fill(LinearGradient(colors: [Color.pink, Color.orange], startPoint: .top, endPoint: .bottom))
                    .frame(width: 30, height: 30)
                    .overlay(
                        Image(systemName: "person.fill")
                            .font(.caption)
                            .foregroundStyle(.white)
                    )
            }

            VStack(alignment: message.isMe ? .trailing : .leading, spacing: 6) {
                if !message.isMe {
                    Text(message.user)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.7))
                }
                Text(message.text)
                    .font(.subheadline)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(
                        Group {
                            if message.isMe {
                                LinearGradient(
                                    colors: [Color.cyan, Color.blue],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            } else {
                                LinearGradient(
                                    colors: [Color.white.opacity(0.15), Color.white.opacity(0.05)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            }
                        }
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(Color.white.opacity(message.isMe ? 0.2 : 0.08), lineWidth: 1)
                    )
            }

            if !message.isMe { Spacer(minLength: 24) }
        }
        .id(message.id)
    }
}

private struct ChatMessage: Identifiable {
    let id = UUID()
    let user: String
    let text: String
    let isMe: Bool
}

private struct EventRow: View {
    let event: Event
    let isGoing: Bool
    let isLive: Bool
    let onGoingTap: () -> Void
    let onDetailsTap: () -> Void

    private var joinBackgroundStyle: AnyShapeStyle {
        if isGoing {
            return AnyShapeStyle(Color.green.opacity(0.2))
        }
        return AnyShapeStyle(
            LinearGradient(
                colors: [Color.cyan.opacity(0.85), Color.blue.opacity(0.85)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
    }

    var body: some View {
        EventsGlassCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top, spacing: 10) {
                    Circle()
                        .fill(isLive ? Color.orange.opacity(0.9) : Color.cyan.opacity(0.85))
                        .frame(width: 34, height: 34)
                        .overlay(
                            Image(systemName: isLive ? "bolt.fill" : "calendar")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.white)
                        )

                    VStack(alignment: .leading, spacing: 4) {
                        Text(event.name)
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(.white)
                            .lineLimit(2)
                        Text(event.location)
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.72))
                            .lineLimit(1)
                    }

                    Spacer()

                    if isLive {
                        Text("LIVE")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 4)
                            .background(.orange.opacity(0.8), in: Capsule())
                    }
                }

                HStack(spacing: 8) {
                    Label(event.dateDisplay, systemImage: "calendar")
                    if let time = event.timeDisplay {
                        Label(time, systemImage: "clock")
                    }
                }
                .font(.caption)
                .foregroundStyle(.white.opacity(0.72))

                if !event.description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text(event.description)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.72))
                        .lineLimit(2)
                }

                HStack(spacing: 8) {
                    Button(action: onGoingTap) {
                        HStack(spacing: 6) {
                            Image(systemName: isGoing ? "checkmark.circle.fill" : "person.crop.circle.badge.plus")
                            Text(isGoing ? "Going" : "I'm Going")
                        }
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(isGoing ? .green.opacity(0.95) : .white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(joinBackgroundStyle, in: RoundedRectangle(cornerRadius: 11, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 11, style: .continuous)
                                .stroke(.white.opacity(0.2), lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)

                    Button(action: onDetailsTap) {
                        Text("Details")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .background(.white.opacity(0.12), in: RoundedRectangle(cornerRadius: 11, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 11, style: .continuous)
                                    .stroke(.white.opacity(0.2), lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

private struct EventDetailSheet: View {
    let event: Event
    @State private var isOpeningMaps = false
    @State private var mapsError: String?

    var body: some View {
        VStack(spacing: 16) {
            Capsule()
                .fill(Color.secondary.opacity(0.4))
                .frame(width: 44, height: 5)
                .padding(.top, 8)

            VStack(spacing: 6) {
                Text(event.name)
                    .font(.title2.bold())
                Text(event.location)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 12) {
                Label(event.dateDisplay, systemImage: "calendar")
                if let time = event.timeDisplay {
                    Label(time, systemImage: "clock")
                }
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)

            if !event.description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text(event.description)
                    .font(.body)
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            if let mapsError {
                Text(mapsError)
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            Button {
                Task { await openInAppleMaps() }
            } label: {
                HStack(spacing: 8) {
                    if isOpeningMaps { ProgressView() }
                    Text("Open in Apple Maps")
                        .font(.headline)
                    Image(systemName: "map")
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Color.blue)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .disabled(isOpeningMaps)

            Spacer()
        }
        .padding(20)
        .presentationDetents([.medium, .large])
        .presentationCornerRadius(24)
    }

    private func openInAppleMaps() async {
        mapsError = nil
        isOpeningMaps = true
        defer { isOpeningMaps = false }

        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = event.location
        request.resultTypes = .address

        do {
            let response = try await MKLocalSearch(request: request).start()
            guard let item = response.mapItems.first else {
                mapsError = "Couldn’t find this location."
                return
            }
            item.name = event.name
            item.openInMaps(launchOptions: [MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDefault])
        } catch {
            mapsError = "Couldn’t open Maps."
        }
    }
}

private struct EventGrouping {
    let activeNow: [Event]
    let upcoming: [Event]

    init(events: [Event], now: Date = Date()) {
        let calendar = Calendar.current
        var active: [Event] = []
        var upcomingList: [Event] = []

        for event in events {
            if Self.isActive(event: event, now: now, calendar: calendar) {
                active.append(event)
            } else if Self.isUpcoming(event: event, now: now, calendar: calendar) {
                upcomingList.append(event)
            }
        }

        activeNow = active
        upcoming = upcomingList
    }

    private static func isActive(event: Event, now: Date, calendar: Calendar) -> Bool {
        guard let date = WTMDateFormatters.eventDateParser.date(from: event.date) else {
            return false
        }

        guard calendar.isDate(date, inSameDayAs: now),
              let start = event.start_time,
              let end = event.end_time,
              let startTime = WTMDateFormatters.timeOnly.date(from: start),
              let endTime = WTMDateFormatters.timeOnly.date(from: end) else {
            return false
        }

        let startComponents = calendar.dateComponents([.hour, .minute, .second], from: startTime)
        let endComponents = calendar.dateComponents([.hour, .minute, .second], from: endTime)

        var startDateComponents = calendar.dateComponents([.year, .month, .day], from: date)
        startDateComponents.hour = startComponents.hour
        startDateComponents.minute = startComponents.minute
        startDateComponents.second = startComponents.second

        var endDateComponents = calendar.dateComponents([.year, .month, .day], from: date)
        endDateComponents.hour = endComponents.hour
        endDateComponents.minute = endComponents.minute
        endDateComponents.second = endComponents.second

        guard let startDateTime = calendar.date(from: startDateComponents),
              let endDateTime = calendar.date(from: endDateComponents) else {
            return false
        }

        return now >= startDateTime && now <= endDateTime.addingTimeInterval(60)
    }

    private static func isUpcoming(event: Event, now: Date, calendar: Calendar) -> Bool {
        guard let date = WTMDateFormatters.eventDateParser.date(from: event.date) else {
            return false
        }

        let startOfToday = calendar.startOfDay(for: now)
        if date > startOfToday {
            return true
        }

        if calendar.isDate(date, inSameDayAs: now) {
            guard let start = event.start_time,
                  let startTime = WTMDateFormatters.timeOnly.date(from: start) else {
                return true
            }

            let startComponents = calendar.dateComponents([.hour, .minute, .second], from: startTime)
            var startDateComponents = calendar.dateComponents([.year, .month, .day], from: date)
            startDateComponents.hour = startComponents.hour
            startDateComponents.minute = startComponents.minute
            startDateComponents.second = startComponents.second

            guard let startDateTime = calendar.date(from: startDateComponents) else {
                return false
            }

            return now < startDateTime
        }

        return false
    }
}

private struct ChatHeader: View {
    let thread: ChatThread
    let onBack: () -> Void
    let onInfo: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button(action: onBack) {
                Image(systemName: "chevron.left")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(width: 36, height: 36)
                    .background(.white.opacity(0.12), in: Circle())
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(thread.title)
                    .font(.headline)
                    .foregroundStyle(.white)
                Text(thread.subtitle)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.7))
            }

            Spacer()

            Button(action: onInfo) {
                Image(systemName: "sparkles")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.8))
                    .padding(8)
                    .background(.white.opacity(0.12), in: Circle())
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 10)
        .background(.ultraThinMaterial.opacity(0.45))
    }
}

private struct ChatInfoSheet: View {
    let thread: ChatThread

    var body: some View {
        VStack(spacing: 16) {
            Capsule()
                .fill(Color.secondary.opacity(0.4))
                .frame(width: 44, height: 5)
                .padding(.top, 8)

            Text(thread.title)
                .font(.title2.bold())
            Text(thread.subtitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            VStack(spacing: 10) {
                Label("Notifications On", systemImage: "bell.badge")
                Label("Participants: 6", systemImage: "person.2.fill")
                Label("Share Invite", systemImage: "square.and.arrow.up")
            }
            .font(.subheadline)

            Spacer()
        }
        .padding(20)
        .presentationDetents([.medium])
        .presentationCornerRadius(24)
    }
}

private struct ChatComposer: View {
    @Binding var messageText: String
    var isFocused: FocusState<Bool>.Binding
    let onSend: () -> Void

    private var canSend: Bool {
        !messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        HStack(spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "bolt.fill")
                    .font(.footnote)
                    .foregroundStyle(.white.opacity(0.7))
                TextField("Message", text: $messageText)
                    .textFieldStyle(.plain)
                    .foregroundStyle(.white)
                    .focused(isFocused)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 12)
            .background(.white.opacity(0.12), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.white.opacity(0.12), lineWidth: 1)
            )

            Button(action: onSend) {
                Image(systemName: "paperplane.fill")
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(
                        LinearGradient(colors: [Color.teal, Color.blue], startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
                    .clipShape(Circle())
                    .shadow(color: .black.opacity(0.25), radius: 8, x: 0, y: 6)
            }
            .disabled(!canSend)
            .opacity(canSend ? 1 : 0.5)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial.opacity(0.45))
    }
}

struct AddEventView: View {
    private enum InputField {
        case title
        case location
        case details
    }

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var dataStore: AppDataStore

    @State private var title = ""
    @State private var date = Date()
    @State private var startTime = Date()
    @State private var endTime = Date()
    @State private var location = ""
    @State private var details = ""
    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var didAppear = false
    @State private var showPostAnimation = false
    @FocusState private var focusedField: InputField?

    var body: some View {
        ZStack {
            AnimatedMeshBackground()
                .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 14) {
                    HStack {
                        Button {
                            dismiss()
                        } label: {
                            Image(systemName: "xmark")
                                .font(.headline)
                                .foregroundStyle(.white)
                                .frame(width: 36, height: 36)
                                .background(.white.opacity(0.12), in: Circle())
                        }
                        .buttonStyle(.plain)

                        Spacer()
                    }

                    EventsGlassCard {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Start a Party")
                                .font(.title2.weight(.bold))
                                .foregroundStyle(.white)
                            Text("Share where you're going so people can join quickly.")
                                .font(.subheadline)
                                .foregroundStyle(.white.opacity(0.72))
                        }
                    }
                    .opacity(didAppear ? 1 : 0)
                    .offset(y: didAppear ? 0 : 8)
                    .animation(.spring(response: 0.6, dampingFraction: 0.85), value: didAppear)

                    EventsGlassCard {
                        VStack(spacing: 12) {
                            eventInputRow("Party name", text: $title, icon: "sparkles", field: .title)
                            eventInputRow("Location", text: $location, icon: "mappin.and.ellipse", field: .location)
                        }
                    }
                    .opacity(didAppear ? 1 : 0)
                    .offset(y: didAppear ? 0 : 14)
                    .animation(.spring(response: 0.7, dampingFraction: 0.85).delay(0.04), value: didAppear)

                    EventsGlassCard {
                        VStack(spacing: 12) {
                            eventPickerRow("Date", icon: "calendar", selection: $date, components: [.date])
                            eventPickerRow("Start time", icon: "clock.fill", selection: $startTime, components: [.hourAndMinute])
                            eventPickerRow("End time", icon: "clock.badge.checkmark.fill", selection: $endTime, components: [.hourAndMinute])
                        }
                    }
                    .opacity(didAppear ? 1 : 0)
                    .offset(y: didAppear ? 0 : 16)
                    .animation(.spring(response: 0.75, dampingFraction: 0.85).delay(0.07), value: didAppear)

                    EventsGlassCard {
                        eventInputRow("Description (optional)", text: $details, icon: "text.alignleft", field: .details, axis: .vertical)
                    }
                    .opacity(didAppear ? 1 : 0)
                    .offset(y: didAppear ? 0 : 16)
                    .animation(.spring(response: 0.75, dampingFraction: 0.85).delay(0.1), value: didAppear)

                    if !isTimeRangeValid {
                        Text("End time should be after start time.")
                            .font(.caption)
                            .foregroundStyle(.red.opacity(0.95))
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    if let errorMessage {
                        Text(errorMessage)
                            .font(.caption)
                            .foregroundStyle(.red.opacity(0.95))
                            .multilineTextAlignment(.leading)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    Button {
                        Task { await saveEvent() }
                    } label: {
                        HStack(spacing: 8) {
                            if isSaving { ProgressView() }
                            Text(isSaving ? "Posting..." : "Post Party")
                                .font(.headline)
                            Image(systemName: "party.popper.fill")
                                .font(.subheadline)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .foregroundStyle(.white)
                        .background(
                            LinearGradient(
                                colors: [Color.cyan.opacity(0.95), Color.blue.opacity(0.9)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(.white.opacity(0.24), lineWidth: 1)
                        )
                        .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 6)
                    }
                    .buttonStyle(.plain)
                    .disabled(!canSubmit || isSaving)
                    .opacity(canSubmit ? 1 : 0.55)
                    .scaleEffect(didAppear ? 1 : 0.98)
                    .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.12), value: didAppear)
                    .overlay {
                        if showPostAnimation {
                            PostBurst()
                                .transition(.opacity)
                        }
                    }

                    Button("Cancel") { dismiss() }
                        .foregroundStyle(.white.opacity(0.75))
                        .padding(.top, 2)
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 34)
            }
            .scrollDismissesKeyboard(.interactively)
            .onAppear {
                didAppear = true
                if Calendar.current.compare(endTime, to: startTime, toGranularity: .minute) != .orderedDescending {
                    endTime = startTime.addingTimeInterval(60 * 60)
                }
            }
        }
    }

    private var isTimeRangeValid: Bool {
        Calendar.current.compare(endTime, to: startTime, toGranularity: .minute) == .orderedDescending
    }

    private var canSubmit: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !location.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        isTimeRangeValid
    }

    private func eventInputRow(
        _ placeholder: String,
        text: Binding<String>,
        icon: String,
        field: InputField,
        axis: Axis = .horizontal
    ) -> some View {
        HStack(alignment: axis == .vertical ? .top : .center, spacing: 10) {
            Image(systemName: icon)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white.opacity(0.82))
                .frame(width: 20)
                .padding(.top, axis == .vertical ? 4 : 0)

            TextField(placeholder, text: text, axis: axis)
                .lineLimit(axis == .vertical ? 3 : 1, reservesSpace: axis == .vertical)
                .foregroundStyle(.white)
                .tint(.white)
                .focused($focusedField, equals: field)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 13)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white.opacity(0.14), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(
                    focusedField == field ? .white.opacity(0.95) : .white.opacity(0.35),
                    lineWidth: focusedField == field ? 1.6 : 1.0
                )
        )
        .shadow(color: .black.opacity(0.18), radius: 8, x: 0, y: 4)
    }

    private func eventPickerRow(
        _ title: String,
        icon: String,
        selection: Binding<Date>,
        components: DatePickerComponents
    ) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white.opacity(0.82))
                .frame(width: 20)

            Text(title)
                .foregroundStyle(.white.opacity(0.92))

            Spacer()

            DatePicker("", selection: selection, displayedComponents: components)
                .labelsHidden()
                .colorScheme(.dark)
                .tint(.white)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 13)
        .frame(maxWidth: .infinity)
        .background(.white.opacity(0.14), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(.white.opacity(0.35), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.18), radius: 8, x: 0, y: 4)
    }

    private func saveEvent() async {
        guard canSubmit else {
            if !isTimeRangeValid {
                errorMessage = "End time should be after start time."
            }
            return
        }

        isSaving = true
        errorMessage = nil
        defer { isSaving = false }

        let payload = EventInsert(
            name: title,
            date: date.onlyDateString(),
            start_time: startTime.onlyTimeString(),
            end_time: endTime.onlyTimeString(),
            location: location,
            description: details
        )

        do {
            _ = try await supabase
                .from("events")
                .insert(payload)
                .execute()
            await dataStore.loadEvents(force: true)
            await MainActor.run {
                showPostAnimation = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                showPostAnimation = false
            }
            await MainActor.run { dismiss() }
        } catch {
            await MainActor.run {
                errorMessage = "Could not save: \(error.localizedDescription)"
            }
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

private struct PostBurst: View {
    @State private var animate = false

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.8), lineWidth: 2)
                .frame(width: 40, height: 40)
                .scaleEffect(animate ? 2.2 : 0.6)
                .opacity(animate ? 0 : 1)
                .animation(.easeOut(duration: 0.6), value: animate)

            Image(systemName: "paperplane.fill")
                .foregroundStyle(.white)
                .scaleEffect(animate ? 1.2 : 0.6)
                .opacity(animate ? 0 : 1)
                .animation(.easeOut(duration: 0.5), value: animate)
        }
        .onAppear { animate = true }
    }
}

#Preview {
    ContentView()
        .environmentObject(AppDataStore())
        .environmentObject(EventPredictionCoordinator())
}
