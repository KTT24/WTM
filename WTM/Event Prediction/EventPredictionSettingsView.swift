import SwiftUI

struct EventPredictionSettingsView: View {
    @StateObject private var settings = EventPredictionSettings.shared

    private var cooldownText: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        return formatter.string(from: settings.suggestionsSuppressedUntil)
    }

    var body: some View {
        Toggle("Discoverable for nearby parties", isOn: $settings.isDiscoverable)
        Toggle("Allow background detection", isOn: $settings.allowBackgroundDetection)
        Toggle("Show party suggestions", isOn: $settings.suggestionsEnabled)

        if settings.isInCooldown {
            HStack {
                Text("Suggestions paused until \(cooldownText)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Resume Now") {
                    settings.clearSuggestionCooldown()
                }
                .buttonStyle(.bordered)
            }
        }
    }
}

#Preview {
    Form {
        Section("Nearby Parties") {
            EventPredictionSettingsView()
        }
    }
}
