//
//  MainTabView.swift
//  WTM
//

import SwiftUI
import Supabase

struct MainTabView: View {
    enum Tab {
        case map
        case upcoming
        case add
        case chats
        case account
    }

    @State private var selectedTab: Tab = .map
    @State private var showAddEvent = false

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
    }
}

private struct CustomTabBar: View {
    @Binding var selectedTab: MainTabView.Tab
    let addAction: () -> Void

    var body: some View {
        HStack(spacing: 26) {
            tabButton(icon: "map", tab: .map)
            tabButton(icon: "calendar", tab: .upcoming)

            Button(action: addAction) {
                ZStack {
                    Circle()
                        .fill(LinearGradient(colors: [Color.mint, Color.blue], startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 66, height: 66)
                        .shadow(color: .black.opacity(0.25), radius: 10, x: 0, y: 6)

                    Image(systemName: "plus")
                        .font(.title.bold())
                        .foregroundStyle(.white)
                }
            }

            tabButton(icon: "bubble.left.and.bubble.right", tab: .chats)
            tabButton(icon: "person", tab: .account)
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 18)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 28))
        .padding(.horizontal, 16)
        .padding(.bottom, 10)
    }

    private func tabButton(icon: String, tab: MainTabView.Tab) -> some View {
        Button {
            selectedTab = tab
        } label: {
            Image(systemName: icon)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(selectedTab == tab ? .white : .white.opacity(0.6))
                .frame(width: 40, height: 40)
                .background(
                    Circle().fill(selectedTab == tab ? Color.white.opacity(0.18) : Color.clear)
                )
        }
    }
}

private struct UpcomingEventsView: View {
    @State private var events: [Event] = []
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Group {
                if isLoading && events.isEmpty {
                    ProgressView("Loading events…")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if events.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "calendar.badge.clock")
                            .font(.system(size: 48))
                            .foregroundStyle(.secondary)
                        Text("Upcoming Events")
                            .font(.title2.bold())
                        Text("Events will show up here once they’re live.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        ForEach(events) { event in
                            VStack(alignment: .leading, spacing: 6) {
                                Text(event.name)
                                    .font(.headline)
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(event.dateDisplay)
                                        if let time = event.timeDisplay {
                                            Text(time)
                                                .font(.caption2)
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                    Spacer()
                                    Text(event.location)
                                }
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                if !event.description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                    Text(event.description)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .padding(.vertical, 6)
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("Upcoming")
            .task {
                await loadEvents()
            }
            .refreshable {
                await loadEvents()
            }
            .overlay(alignment: .bottom) {
                if let errorMessage {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .padding(.bottom, 8)
                }
            }
        }
    }

    private func loadEvents() async {
        isLoading = true
        defer { isLoading = false }

        do {
            let fetched: [Event] = try await supabase
                .from("events")
                .select()
                .order("date", ascending: true)
                .execute()
                .value
            await MainActor.run {
                events = fetched
                errorMessage = nil
            }
        } catch {
            await MainActor.run {
                errorMessage = "Failed to load events: \(error.localizedDescription)"
            }
        }
    }
}

private struct ChatsView: View {
    @State private var bars: [Bars] = []
    @State private var events: [Event] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var selectedChat: ChatThread?

    var body: some View {
        NavigationStack {
            Group {
                if isLoading && bars.isEmpty && events.isEmpty {
                    ProgressView("Loading chats…")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if bars.isEmpty && events.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "bubble.left.and.bubble.right")
                            .font(.system(size: 48))
                            .foregroundStyle(.secondary)
                        Text("Chats")
                            .font(.title2.bold())
                        Text("Group chats will appear for bars and live events.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        if !events.isEmpty {
                            Section("Live Events") {
                                ForEach(events) { event in
                                    let thread = ChatThread.event(id: event.id, title: event.name, subtitle: event.location)
                                    HStack(spacing: 12) {
                                        Circle()
                                            .fill(Color.orange.opacity(0.2))
                                            .frame(width: 40, height: 40)
                                            .overlay(
                                                Image(systemName: "bolt.fill")
                                                    .foregroundStyle(.orange)
                                            )
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(event.name)
                                                .font(.headline)
                                            Text(event.location)
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                        Spacer()
                                        Text("Live")
                                            .font(.caption2.bold())
                                            .foregroundStyle(.white)
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 4)
                                            .background(Color.orange)
                                            .clipShape(Capsule())
                                    }
                                    .padding(.vertical, 4)
                                    .contentShape(Rectangle())
                                    .onTapGesture { selectedChat = thread }
                                }
                            }
                        }

                        if !bars.isEmpty {
                            Section("Bars") {
                                ForEach(bars) { bar in
                                    let thread = ChatThread.bar(id: bar.id, title: bar.name, subtitle: bar.address)
                                    HStack(spacing: 12) {
                                        Circle()
                                            .fill(Color.blue.opacity(0.2))
                                            .frame(width: 40, height: 40)
                                            .overlay(
                                                Image(systemName: "wineglass.fill")
                                                    .foregroundStyle(.blue)
                                            )
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(bar.name)
                                                .font(.headline)
                                            Text(bar.address)
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                        Spacer()
                                        Image(systemName: "chevron.right")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    .padding(.vertical, 4)
                                    .contentShape(Rectangle())
                                    .onTapGesture { selectedChat = thread }
                                }
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("Chats")
            .task {
                await loadChats()
            }
            .refreshable {
                await loadChats()
            }
            .overlay(alignment: .bottom) {
                if let errorMessage {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .padding(.bottom, 8)
                }
            }
            .fullScreenCover(item: $selectedChat) { thread in
                ChatRoomView(thread: thread)
            }
        }
    }

    private func loadChats() async {
        isLoading = true
        defer { isLoading = false }

        do {
            async let barsReq: [Bars] = supabase
                .from("bars")
                .select()
                .order("name", ascending: true)
                .execute()
                .value

            async let eventsReq: [Event] = supabase
                .from("events")
                .select()
                .order("date", ascending: true)
                .execute()
                .value

            let (barsData, eventsData) = try await (barsReq, eventsReq)
            await MainActor.run {
                bars = barsData
                events = eventsData
                errorMessage = nil
            }
        } catch {
            await MainActor.run {
                errorMessage = "Failed to load chats: \(error.localizedDescription)"
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

    private let messages: [ChatMessage] = [
        ChatMessage(user: "Ava", text: "Pulling up in 10. Who’s already there?", isMe: false),
        ChatMessage(user: "You", text: "I’m on the way now.", isMe: true),
        ChatMessage(user: "Miles", text: "Table by the patio is open.", isMe: false),
        ChatMessage(user: "Jules", text: "Let’s do a round of shots when everyone’s here.", isMe: false),
        ChatMessage(user: "You", text: "Bet. I’ll grab a pitcher too.", isMe: true),
        ChatMessage(user: "Nova", text: "ETA 5 min 🚗", isMe: false)
    ]

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.headline)
                        .padding(8)
                }
                Spacer()
                VStack(spacing: 4) {
                    Text(thread.title)
                        .font(.headline)
                    Text(thread.subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Color.clear.frame(width: 32, height: 32)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)

            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(messages) { message in
                        MessageBubble(message: message)
                    }
                }
                .padding(16)
            }

            HStack(spacing: 10) {
                TextField("Message", text: $messageText)
                    .textFieldStyle(.roundedBorder)

                Button {
                    messageText = ""
                } label: {
                    Image(systemName: "paperplane.fill")
                        .foregroundStyle(.white)
                        .padding(10)
                        .background(Color.blue)
                        .clipShape(Circle())
                }
                .disabled(messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding(12)
            .background(.ultraThinMaterial)
        }
    }
}

private struct MessageBubble: View {
    let message: ChatMessage

    var body: some View {
        HStack {
            if message.isMe { Spacer() }
            if !message.isMe {
                Circle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 28, height: 28)
                    .overlay(
                        Image(systemName: "person.fill")
                            .font(.caption)
                            .foregroundStyle(.white)
                    )
            }
            VStack(alignment: message.isMe ? .trailing : .leading, spacing: 4) {
                if !message.isMe {
                    Text(message.user)
                        .font(.caption2.bold())
                        .foregroundStyle(.secondary)
                }
                Text(message.text)
                    .font(.subheadline)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(message.isMe ? Color.blue : Color.gray.opacity(0.2))
                    .foregroundStyle(message.isMe ? .white : .primary)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            if !message.isMe { Spacer() }
        }
    }
}

private struct ChatMessage: Identifiable {
    let id = UUID()
    let user: String
    let text: String
    let isMe: Bool
}

private struct AddEventView: View {
    @Environment(\.dismiss) private var dismiss

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

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color.mint.opacity(0.35), Color.blue.opacity(0.25), Color.purple.opacity(0.2)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 18) {
                VStack(spacing: 6) {
                    Text("Create Event")
                        .font(.title.bold())
                    Text("Share the vibe with everyone")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .opacity(didAppear ? 1 : 0)
                .offset(y: didAppear ? 0 : 12)
                .animation(.spring(response: 0.6, dampingFraction: 0.85), value: didAppear)

                VStack(spacing: 12) {
                    fieldCard {
                        TextField("Event name", text: $title)
                    }
                    fieldCard {
                        DatePicker("Date", selection: $date, displayedComponents: [.date])
                    }
                    fieldCard {
                        DatePicker("Start time", selection: $startTime, displayedComponents: [.hourAndMinute])
                    }
                    fieldCard {
                        DatePicker("End time", selection: $endTime, displayedComponents: [.hourAndMinute])
                    }
                    fieldCard {
                        TextField("Location", text: $location)
                    }
                    fieldCard {
                        TextField("Description", text: $details, axis: .vertical)
                            .lineLimit(3, reservesSpace: true)
                    }
                }
                .opacity(didAppear ? 1 : 0)
                .offset(y: didAppear ? 0 : 16)
                .animation(.spring(response: 0.7, dampingFraction: 0.85).delay(0.05), value: didAppear)

                if let errorMessage {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                        .padding(.top, 4)
                }

                Button {
                    Task { await saveEvent() }
                } label: {
                    HStack(spacing: 8) {
                        if isSaving { ProgressView() }
                        Text(isSaving ? "Saving..." : "Post Event")
                            .font(.headline)
                        Image(systemName: "sparkles")
                            .font(.subheadline)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        LinearGradient(
                            colors: [Color.blue, Color.mint],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 6)
                }
                .disabled(!canSubmit || isSaving)
                .scaleEffect(didAppear ? 1 : 0.98)
                .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.1), value: didAppear)
                .overlay {
                    if showPostAnimation {
                        PostBurst()
                            .transition(.opacity)
                    }
                }

                Button("Cancel") { dismiss() }
                    .foregroundStyle(.secondary)
                    .padding(.top, 4)
            }
            .padding(20)
            .onAppear { didAppear = true }
        }
    }

    private var canSubmit: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !location.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func fieldCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .padding(12)
            .frame(maxWidth: .infinity)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
    }

    private func saveEvent() async {
        guard canSubmit else { return }
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

private struct Event: Identifiable, Decodable {
    let id: Int
    let name: String
    let date: String
    let start_time: String?
    let end_time: String?
    let location: String
    let description: String

    var dateDisplay: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        if let parsed = formatter.date(from: date) {
            formatter.dateStyle = .medium
            formatter.timeStyle = .none
            return formatter.string(from: parsed)
        }
        return date
    }

    var timeDisplay: String? {
        guard let start_time, !start_time.isEmpty else { return nil }
        let end = end_time ?? ""
        return end.isEmpty ? start_time : "\(start_time) – \(end)"
    }
}

private extension Date {
    func onlyDateString() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: self)
    }

    func onlyTimeString() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter.string(from: self)
    }
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
    MainTabView()
}
