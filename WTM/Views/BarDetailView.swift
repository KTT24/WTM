//
//  BarDetailView.swift
//  WTM
//
//  Created by Kutter Thornton on 2/6/26.
//

import SwiftUI
import MapKit

struct BarDetailView: View {
    let bar: Bars

    @EnvironmentObject private var dataStore: AppDataStore
    @Environment(\.colorScheme) private var colorScheme

    @State private var displayBar: Bars
    @State private var currentPeopleCount: Int
    @State private var currentHypeScore: Int
    @State private var region: MKCoordinateRegion
    @State private var errorMessage: String?
    @State private var isUpdating = false
    @State private var isLoadingDetails = false

    init(bar: Bars) {
        self.bar = bar
        self._displayBar = State(initialValue: bar)
        self._currentPeopleCount = State(initialValue: bar.people_count)
        self._currentHypeScore = State(initialValue: bar.hype_score)

        let center = bar.coordinate
        self._region = State(initialValue: MKCoordinateRegion(
            center: center,
            span: MKCoordinateSpan(latitudeDelta: 0.008, longitudeDelta: 0.008)
        ))
    }

    var body: some View {
        ZStack {
            AnimatedMeshBackground()
                .blur(radius: 28)
                .ignoresSafeArea()
            Color.black
                .opacity(AdaptiveTheme.backgroundScrimOpacity(for: colorScheme))
                .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 14) {
                    headerCard
                    actionCard
                    mapCard
                    detailsCard
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 18)
            }
        }
        .navigationTitle(displayBar.name)
        .navigationBarTitleDisplayMode(.inline)
        .task(id: bar.id) {
            await refreshBarDetails()
        }
    }

    private var headerCard: some View {
        DetailGlassCard {
            VStack(alignment: .leading, spacing: 10) {
                Text(displayBar.name)
                    .font(.title2.weight(.bold))
                    .foregroundStyle(.white)

                HStack(spacing: 10) {
                    DetailStatPill(
                        title: "Hype",
                        value: "\(currentHypeScore)/10",
                        tint: hypeTintColor
                    )

                    DetailStatPill(
                        title: "Here Now",
                        value: "\(currentPeopleCount)",
                        tint: .cyan
                    )

                    DetailStatPill(
                        title: "Popularity",
                        value: "\(displayBar.popularity)",
                        tint: .orange
                    )
                }
            }
        }
    }

    private var actionCard: some View {
        DetailGlassCard {
            VStack(alignment: .leading, spacing: 10) {
                Text("Update Crowd")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.95))

                HStack(spacing: 10) {
                    Button {
                        Task { await updateCounts(delta: 1) }
                    } label: {
                        ActionButtonLabel(
                            title: "I'm here",
                            icon: "person.fill.checkmark",
                            tint: .blue
                        )
                    }
                    .buttonStyle(.plain)
                    .disabled(isUpdating)

                    Button {
                        Task { await updateCounts(delta: -1) }
                    } label: {
                        ActionButtonLabel(
                            title: "I left",
                            icon: "person.fill.xmark",
                            tint: .red
                        )
                    }
                    .buttonStyle(.plain)
                    .disabled(isUpdating)
                }

                if let errorMessage {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundStyle(.red.opacity(0.95))
                }
            }
        }
    }

    private var mapCard: some View {
        DetailGlassCard {
            VStack(alignment: .leading, spacing: 10) {
                Text("Location")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.95))

                Map(coordinateRegion: .constant(region), interactionModes: [])
                .frame(height: 180)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(.white.opacity(0.2), lineWidth: 1)
                )
            }
        }
    }

    private var detailsCard: some View {
        DetailGlassCard {
            VStack(alignment: .leading, spacing: 12) {
                if let category = parsedInternetDetails.category {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Category")
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.95))
                        Text(category)
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.78))
                    }
                }

                if let phone = parsedInternetDetails.phone {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Phone")
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.95))
                        if let telURL = telURL(for: phone) {
                            Link(phone, destination: telURL)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.cyan)
                        } else {
                            Text(phone)
                                .font(.subheadline)
                                .foregroundStyle(.white.opacity(0.78))
                        }
                    }
                }

                if let websiteURL = parsedInternetDetails.websiteURL {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Website")
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.95))
                        Link(parsedInternetDetails.websiteDisplay ?? websiteURL.absoluteString, destination: websiteURL)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.cyan)
                    }
                }

                if !aboutText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("About")
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.95))
                        Text(aboutText)
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.78))
                    }
                }

                if !displayBar.address.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Address")
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.95))
                        Text(displayBar.address)
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.78))
                    }
                }
            }
        }
    }

    private var hypeTintColor: Color {
        if currentHypeScore >= 7 { return .orange }
        if currentHypeScore >= 5 { return .yellow }
        return .green
    }

    private var parsedInternetDetails: ParsedInternetDetails {
        ParsedInternetDetails.parse(from: displayBar.description)
    }

    private var aboutText: String {
        if parsedInternetDetails.containsMetadata {
            return parsedInternetDetails.about ?? ""
        }
        return displayBar.description
    }

    private func updateCounts(delta: Int) async {
        guard !isUpdating else { return }
        isUpdating = true
        defer { isUpdating = false }

        do {
            let newPeople = max(0, currentPeopleCount + delta)
            let newHype = min(10, newPeople / 4)

            let updatedBar = displayBar.updating(peopleCount: newPeople, hypeScore: newHype)
            let resolvedBar = try await dataStore.recordVisit(for: updatedBar)

            await MainActor.run {
                displayBar = resolvedBar
                currentPeopleCount = newPeople
                currentHypeScore = newHype
                region.center = resolvedBar.coordinate
                errorMessage = nil
            }
        } catch {
            await MainActor.run {
                errorMessage = "Failed to update: \(error.localizedDescription)"
            }
        }
    }

    private func refreshBarDetails() async {
        guard !isLoadingDetails else { return }
        isLoadingDetails = true
        defer { isLoadingDetails = false }

        let resolved = await dataStore.resolveBarDetails(for: displayBar)
        await MainActor.run {
            displayBar = resolved
            currentPeopleCount = resolved.people_count
            currentHypeScore = resolved.hype_score
            region.center = resolved.coordinate
        }
    }

    private func telURL(for phone: String) -> URL? {
        let allowed = Set("+0123456789")
        let normalized = phone.filter { allowed.contains($0) }
        guard !normalized.isEmpty else { return nil }
        return URL(string: "tel://\(normalized)")
    }
}

private struct ParsedInternetDetails {
    var category: String?
    var phone: String?
    var websiteURL: URL?
    var websiteDisplay: String?
    var about: String?
    var containsMetadata = false

    static func parse(from description: String) -> ParsedInternetDetails {
        let trimmed = description.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return ParsedInternetDetails() }

        var result = ParsedInternetDetails()
        var leftovers: [String] = []
        let normalized = trimmed.replacingOccurrences(of: "\n", with: " • ")
        let parts = normalized
            .components(separatedBy: "•")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        for part in parts {
            let lower = part.lowercased()
            if lower.hasPrefix("category:") {
                result.category = value(after: "Category:", in: part)
                result.containsMetadata = true
                continue
            }
            if lower.hasPrefix("phone:") {
                result.phone = value(after: "Phone:", in: part)
                result.containsMetadata = true
                continue
            }
            if lower.hasPrefix("website:") {
                let raw = value(after: "Website:", in: part)
                if let parsed = normalizedWebsite(raw) {
                    result.websiteURL = parsed
                    result.websiteDisplay = parsed.host ?? raw
                }
                result.containsMetadata = true
                continue
            }
            leftovers.append(part)
        }

        if !leftovers.isEmpty {
            result.about = leftovers.joined(separator: " • ")
        }

        return result
    }

    private static func value(after prefix: String, in text: String) -> String {
        guard let range = text.range(of: prefix, options: [.caseInsensitive, .anchored]) else {
            return text.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return text[range.upperBound...].trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func normalizedWebsite(_ value: String) -> URL? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        if let direct = URL(string: trimmed), direct.scheme != nil {
            return direct
        }
        return URL(string: "https://\(trimmed)")
    }
}

private struct DetailGlassCard<Content: View>: View {
    @Environment(\.colorScheme) private var colorScheme
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            content
        }
        .padding(14)
        .background(AdaptiveTheme.cardFill(for: colorScheme), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(AdaptiveTheme.cardStroke(for: colorScheme), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.2), radius: 12, x: 0, y: 6)
    }
}

private struct DetailStatPill: View {
    @Environment(\.colorScheme) private var colorScheme
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
        .background(tint.opacity(colorScheme == .dark ? 0.24 : 0.32), in: RoundedRectangle(cornerRadius: 11, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .stroke(AdaptiveTheme.controlStroke(for: colorScheme), lineWidth: 1)
        )
    }
}

private struct ActionButtonLabel: View {
    @Environment(\.colorScheme) private var colorScheme
    let title: String
    let icon: String
    let tint: Color

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
            Text(title)
                .font(.subheadline.weight(.semibold))
        }
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(tint.opacity(colorScheme == .dark ? 0.35 : 0.5), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(AdaptiveTheme.controlStroke(for: colorScheme), lineWidth: 1)
        )
    }
}
