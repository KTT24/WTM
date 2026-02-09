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

    @State private var currentPeopleCount: Int
    @State private var currentHypeScore: Int
    @State private var region: MKCoordinateRegion
    @State private var errorMessage: String?
    @State private var isUpdating = false

    init(bar: Bars) {
        self.bar = bar
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
//            AnimatedMeshBackground()
//                .blur(radius: 28)
//                .ignoresSafeArea()

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
        .navigationTitle(bar.name)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var headerCard: some View {
        DetailGlassCard {
            VStack(alignment: .leading, spacing: 10) {
                Text(bar.name)
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
                        value: "\(bar.popularity)",
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
                if !bar.description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("About")
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.95))
                        Text(bar.description)
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.78))
                    }
                }

                if !bar.address.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Address")
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.95))
                        Text(bar.address)
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

    private func updateCounts(delta: Int) async {
        guard !isUpdating else { return }
        isUpdating = true
        defer { isUpdating = false }

        do {
            let newPeople = max(0, currentPeopleCount + delta)
            let newHype = min(10, newPeople / 4)

            let updatedBar = bar.updating(peopleCount: newPeople, hypeScore: newHype)
            try await dataStore.recordVisit(for: updatedBar)

            await MainActor.run {
                currentPeopleCount = newPeople
                currentHypeScore = newHype
                errorMessage = nil
            }
        } catch {
            await MainActor.run {
                errorMessage = "Failed to update: \(error.localizedDescription)"
            }
        }
    }
}

private struct DetailGlassCard<Content: View>: View {
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
        .shadow(color: .black.opacity(0.2), radius: 12, x: 0, y: 6)
    }
}

private struct DetailStatPill: View {
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
        .background(tint.opacity(0.24), in: RoundedRectangle(cornerRadius: 11, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .stroke(.white.opacity(0.2), lineWidth: 1)
        )
    }
}

private struct ActionButtonLabel: View {
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
        .background(tint.opacity(0.35), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(.white.opacity(0.22), lineWidth: 1)
        )
    }
}
