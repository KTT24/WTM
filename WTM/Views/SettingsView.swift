import SwiftUI
import CoreLocation

enum AccountAccentOption: String, CaseIterable, Identifiable {
    case cyan
    case blue
    case green
    case orange
    case pink
    case red

    var id: String { rawValue }

    var title: String {
        rawValue.capitalized
    }

    var accentColor: Color {
        switch self {
        case .cyan: return .cyan
        case .blue: return .blue
        case .green: return .green
        case .orange: return .orange
        case .pink: return .pink
        case .red: return .red
        }
    }

    var secondaryColor: Color {
        switch self {
        case .cyan: return .mint
        case .blue: return .indigo
        case .green: return .teal
        case .orange: return .yellow
        case .pink: return .purple
        case .red: return .orange
        }
    }
}

struct SettingsView: View {
    @EnvironmentObject private var dataStore: AppDataStore
    @EnvironmentObject private var eventPredictionCoordinator: EventPredictionCoordinator

    @AppStorage("enableNotifications") private var enableNotifications: Bool = true
    @AppStorage("enableWeekendPromptsNotifications") private var enableWeekendPromptsNotifications: Bool = true
    @AppStorage("enableNewEventNotifications") private var enableNewEventNotifications: Bool = true
    @AppStorage("enableEventChatNotifications") private var enableEventChatNotifications: Bool = true
    @AppStorage("minHypeToShow") private var minHypeToShow: Int = 0
    @AppStorage("defaultPrimaryTab") private var defaultPrimaryTabRaw: String = "map"
    @AppStorage("showCurrentPartyMarkers") private var showCurrentPartyMarkers: Bool = true
    @AppStorage("accountAccentColor") private var accountAccentColorRaw: String = AccountAccentOption.cyan.rawValue
    @AppStorage("isLoggedIn") private var isLoggedIn: Bool = false

    @State private var showingClearConfirmation = false
    @State private var debugLocationInput = ""
    @State private var debugLocationMessage: String?
    @State private var notificationMessage: String?

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: [Color.black, Color(red: 0.07, green: 0.11, blue: 0.13)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 14) {
                        GlassSection(title: "Notifications") {
                            VStack(spacing: 12) {
                                Toggle("Push Notifications", isOn: $enableNotifications)
                                    .onChange(of: enableNotifications) { _ in
                                        Task {
                                            await applyNotificationPreferences()
                                        }
                                    }

                                Toggle("Weekend 10 PM prompts", isOn: $enableWeekendPromptsNotifications)
                                    .disabled(!enableNotifications)
                                    .onChange(of: enableWeekendPromptsNotifications) { _ in
                                        Task { await applyNotificationPreferences() }
                                    }

                                Toggle("New event posted", isOn: $enableNewEventNotifications)
                                    .disabled(!enableNotifications)
                                    .onChange(of: enableNewEventNotifications) { _ in
                                        Task { await applyNotificationPreferences() }
                                    }

                                Toggle("Event chat updates", isOn: $enableEventChatNotifications)
                                    .disabled(!enableNotifications)
                                    .onChange(of: enableEventChatNotifications) { _ in
                                        Task { await applyNotificationPreferences() }
                                    }

                                if let notificationMessage {
                                    Text(notificationMessage)
                                        .font(.caption)
                                        .foregroundStyle(.white.opacity(0.7))
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                            }
                        }

                        GlassSection(title: "Nearby Parties") {
                            EventPredictionSettingsView()
                        }

                        GlassSection(title: "App Customization") {
                            VStack(spacing: 12) {
                                

                                Toggle("Show current party markers", isOn: $showCurrentPartyMarkers)

                                Picker("Show hype markers >=", selection: $minHypeToShow) {
                                    Text("All").tag(0)
                                    Text("5+").tag(5)
                                    Text("8+").tag(8)
                                }
                                .pickerStyle(.segmented)

                                accountAccentPicker
                            }
                        }

                        GlassSection(title: "Debug") {
                            VStack(spacing: 10) {
                                Button {
                                    eventPredictionCoordinator.injectDebugSuggestion()
                                } label: {
                                    SettingsActionLabel(
                                        title: "Inject Fake Party Suggestion",
                                        icon: "sparkles"
                                    )
                                }
                                .buttonStyle(.plain)

                                Button {
                                    Task { await dataStore.insertFakeEvents(count: 5) }
                                } label: {
                                    SettingsActionLabel(
                                        title: "Add 5 Fake Parties",
                                        icon: "party.popper.fill"
                                    )
                                }
                                .buttonStyle(.plain)

                                Button {
                                    Task {
                                        let sent = await NotificationManager.shared.sendDebugTestNotification()
                                        await MainActor.run {
                                            notificationMessage = sent
                                                ? "Test notification queued."
                                                : "Notifications are blocked in iOS Settings."
                                        }
                                    }
                                } label: {
                                    SettingsActionLabel(
                                        title: "Send Test Notification",
                                        icon: "bell.and.waves.left.and.right.fill"
                                    )
                                }
                                .buttonStyle(.plain)

                                Button {
                                    isLoggedIn = false
                                } label: {
                                    SettingsActionLabel(
                                        title: "Show Onboarding Again",
                                        icon: "arrow.counterclockwise"
                                    )
                                }
                                .buttonStyle(.plain)

                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Set Debug Location (lat, lon)")
                                        .font(.subheadline)
                                        .foregroundStyle(.white.opacity(0.78))

                                    TextField("e.g. 33.5779, -101.8552", text: $debugLocationInput)
                                        .textInputAutocapitalization(.never)
                                        .autocorrectionDisabled(true)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 10)
                                        .background(.white.opacity(0.12), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                                .stroke(.white.opacity(0.25), lineWidth: 1)
                                        )

                                    HStack(spacing: 10) {
                                        Button("Apply") {
                                            applyDebugLocation()
                                        }
                                        .buttonStyle(.borderedProminent)

                                        Button("Clear") {
                                            DebugLocationStore.clearOverride()
                                            debugLocationMessage = "Debug location cleared."
                                        }
                                        .buttonStyle(.bordered)
                                    }

                                    if let current = DebugLocationStore.currentOverride() {
                                        Text("Current: \(current.coordinate.latitude), \(current.coordinate.longitude)")
                                            .font(.caption)
                                            .foregroundStyle(.white.opacity(0.7))
                                    }

                                    if let debugLocationMessage {
                                        Text(debugLocationMessage)
                                            .font(.caption)
                                            .foregroundStyle(.white.opacity(0.7))
                                    }
                                }
                                .padding(.top, 4)
                            }
                        }

                        GlassSection(title: "Storage") {
                            Button(role: .destructive) {
                                showingClearConfirmation = true
                            } label: {
                                SettingsActionLabel(
                                    title: "Clear Cached Bars",
                                    icon: "trash"
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 18)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .confirmationDialog(
                "Clear Cached Bars?",
                isPresented: $showingClearConfirmation
            ) {
                Button("Clear", role: .destructive) {
                    dataStore.clearBars()
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("This only clears the local list. It won't delete data in Supabase.")
            }
            .task {
                NotificationManager.shared.configure()
                await NotificationManager.shared.syncScheduledNotifications(
                    preferences: notificationPreferences,
                    goingEvents: dataStore.goingEvents
                )
            }
        }
    }

    private func applyDebugLocation() {
        let parts = debugLocationInput.split(separator: ",")
        guard parts.count == 2,
              let lat = Double(parts[0].trimmingCharacters(in: .whitespaces)),
              let lon = Double(parts[1].trimmingCharacters(in: .whitespaces)),
              lat >= -90, lat <= 90, lon >= -180, lon <= 180
        else {
            debugLocationMessage = "Enter a valid lat, lon (e.g. 33.5779, -101.8552)."
            return
        }

        DebugLocationStore.setOverride(latitude: lat, longitude: lon)
        debugLocationMessage = "Debug location set."
    }

    private var notificationPreferences: NotificationPreferences {
        NotificationPreferences(
            masterEnabled: enableNotifications,
            weekendPromptsEnabled: enableWeekendPromptsNotifications,
            newEventsEnabled: enableNewEventNotifications,
            eventChatsEnabled: enableEventChatNotifications
        )
    }

    private func applyNotificationPreferences() async {
        if enableNotifications {
            let granted = await NotificationManager.shared.requestAuthorizationIfNeeded()
            if !granted {
                await MainActor.run {
                    enableNotifications = false
                    notificationMessage = "Enable notifications in iOS Settings to turn this on."
                }
                return
            }
        }

        await NotificationManager.shared.syncScheduledNotifications(
            preferences: notificationPreferences,
            goingEvents: dataStore.goingEvents
        )

        await MainActor.run {
            notificationMessage = enableNotifications ? nil : "Notifications are off."
        }
    }

    private var selectedAccentOption: AccountAccentOption {
        AccountAccentOption(rawValue: accountAccentColorRaw) ?? .cyan
    }

    private var accountAccentPicker: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Account Accent Color")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white.opacity(0.86))

            HStack(spacing: 10) {
                ForEach(AccountAccentOption.allCases) { option in
                    Button {
                        accountAccentColorRaw = option.rawValue
                    } label: {
                        ZStack {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [option.accentColor, option.secondaryColor],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 30, height: 30)

                            if selectedAccentOption == option {
                                Image(systemName: "checkmark")
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(.white)
                            }
                        }
                        .overlay(
                            Circle()
                                .stroke(
                                    selectedAccentOption == option ? .white.opacity(0.95) : .white.opacity(0.28),
                                    lineWidth: selectedAccentOption == option ? 2 : 1
                                )
                        )
                        .shadow(color: .black.opacity(0.25), radius: 5, x: 0, y: 2)
                        .accessibilityLabel(option.title)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

private struct GlassSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline.weight(.semibold))
                .foregroundStyle(.white.opacity(0.92))

            content
        }
        .padding(14)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(.white.opacity(0.24), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.2), radius: 12, x: 0, y: 6)
    }
}

private struct SettingsActionLabel: View {
    let title: String
    let icon: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.subheadline.weight(.semibold))
                .frame(width: 18)

            Text(title)
                .font(.subheadline.weight(.semibold))

            Spacer()
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 12)
        .padding(.vertical, 11)
        .background(.white.opacity(0.12), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(.white.opacity(0.22), lineWidth: 1)
        )
    }
}

#Preview {
    SettingsView()
        .environmentObject(AppDataStore())
        .environmentObject(EventPredictionCoordinator())
}
