//
//  AccountView.swift
//  WTM
//

import SwiftUI

struct AccountView: View {
    @EnvironmentObject private var dataStore: AppDataStore
    @AppStorage("minHypeToShow") private var minHypeToShow: Int = 0
    @AppStorage("accountAccentColor") private var accountAccentColorRaw: String = AccountAccentOption.cyan.rawValue

    @State private var showAllBars = false
    @State private var showSettings = false

    private var filteredBars: [Bars] {
        let sortedBars = dataStore.visitedBars.sorted { $0.hype_score > $1.hype_score }
        if minHypeToShow == 0 { return sortedBars }
        return sortedBars.filter { $0.hype_score >= minHypeToShow }
    }

    private var displayedBars: [Bars] {
        if showAllBars || filteredBars.count <= 10 {
            return filteredBars
        }
        return Array(filteredBars.prefix(10))
    }

    private var hasMoreToShow: Bool {
        filteredBars.count > 10 && !showAllBars
    }

    private var averageHype: String {
        guard !filteredBars.isEmpty else { return "0.0" }
        let total = filteredBars.reduce(0) { $0 + $1.hype_score }
        let avg = Double(total) / Double(filteredBars.count)
        return String(format: "%.1f", avg)
    }

    private var selectedAccent: AccountAccentOption {
        AccountAccentOption(rawValue: accountAccentColorRaw) ?? .cyan
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AnimatedMeshBackground(
                    accentColor: selectedAccent.accentColor,
                    secondaryAccentColor: selectedAccent.secondaryColor
                )
                .blur(radius: 30)
                .ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 14) {
                        accountHero
                        visitedBarsSection
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 18)
                }
            }
            .navigationTitle("Account")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: "gearshape.fill")
                    }
                }
            }
            .sheet(isPresented: $showSettings) {
                SettingsView()
            }
            .task {
                await dataStore.loadBars()
            }
        }
    }

    private var accountHero: some View {
        GlassCard {
            HStack(spacing: 14) {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                selectedAccent.accentColor.opacity(0.95),
                                selectedAccent.secondaryColor.opacity(0.7)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 70, height: 70)
                    .overlay(
                        Image(systemName: "person.fill")
                            .font(.system(size: 30, weight: .semibold))
                            .foregroundStyle(.white)
                    )

                VStack(alignment: .leading, spacing: 4) {
                    Text("KUTTER THORNTON")
                        .font(.title3.weight(.bold))
                        .foregroundStyle(.white)
                    Text("@kutter_thornton")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.72))
                }

                Spacer()
            }

            HStack(spacing: 10) {
                AccountStatPill(title: "Visited", value: "\(filteredBars.count)")
                AccountStatPill(title: "Avg Hype", value: averageHype)
                AccountStatPill(title: "Filter", value: minHypeToShow == 0 ? "All" : "\(minHypeToShow)+")
            }
            .padding(.top, 8)
        }
    }

    private var visitedBarsSection: some View {
        GlassCard {
            HStack {
                Text("Visited Bars")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.94))
                Spacer()
                Text("\(filteredBars.count) total")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.7))
            }

            if dataStore.isLoadingBars {
                HStack(spacing: 8) {
                    ProgressView()
                    Text("Loading bars...")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.72))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 10)
            } else if displayedBars.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "mappin.slash.circle")
                        .font(.system(size: 34))
                        .foregroundStyle(.white.opacity(0.78))
                    Text("No Bars Yet")
                        .font(.headline)
                        .foregroundStyle(.white)
                    Text("Bars you've visited will appear here once loaded.")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.72))
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
            } else {
                VStack(spacing: 8) {
                    ForEach(displayedBars) { bar in
                        VisitedBarRow(bar: bar)
                    }
                }
                .padding(.top, 4)

                if hasMoreToShow || showAllBars {
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            showAllBars.toggle()
                        }
                    } label: {
                        Text(showAllBars ? "Show Less" : "Show More (\(filteredBars.count - 10) more)")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 11)
                            .background(.white.opacity(0.12), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .stroke(.white.opacity(0.22), lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 8)
                }
            }

            if let errorMessage = dataStore.barsError {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red.opacity(0.95))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 8)
            }
        }
    }
}

private struct GlassCard<Content: View>: View {
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

private struct AccountStatPill: View {
    let title: String
    let value: String

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
        .background(.white.opacity(0.12), in: RoundedRectangle(cornerRadius: 11, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .stroke(.white.opacity(0.22), lineWidth: 1)
        )
    }
}

private struct VisitedBarRow: View {
    let bar: Bars

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(bar.hypeColor.opacity(0.9))
                .frame(width: 34, height: 34)
                .overlay(
                    Image(systemName: "wineglass.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white)
                )

            VStack(alignment: .leading, spacing: 3) {
                Text(bar.name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)

                if !bar.address.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text(bar.address)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.68))
                        .lineLimit(1)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text("Hype \(bar.hype_score)/10")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.78))
                Text("\(bar.people_count) ppl")
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.68))
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(.white.opacity(0.1), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(.white.opacity(0.18), lineWidth: 1)
        )
    }
}

#Preview {
    AccountView()
        .environmentObject(AppDataStore())
}
