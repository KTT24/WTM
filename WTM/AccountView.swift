//
//  AccountView.swift
//  WTM
//

import SwiftUI
import Supabase

struct AccountView: View {
    @State private var bars: [Bars] = []
    @State private var isLoading = false
    @State private var errorMessage: String?

    @AppStorage("isDarkMode") private var isDarkMode: Bool = false
    @AppStorage("enableNotifications") private var enableNotifications: Bool = true
    @AppStorage("minHypeToShow") private var minHypeToShow: Int = 0

    @State private var showAllBars = false
    @State private var showingClearConfirmation = false

    private var filteredBars: [Bars] {
        if minHypeToShow == 0 { return bars }
        return bars.filter { $0.hype_score >= minHypeToShow }
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

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack(spacing: 16) {
                        Image(systemName: "person.circle.fill")
                            .resizable()
                            .frame(width: 70, height: 70)
                            .foregroundStyle(.blue.gradient)
                            .background(Circle().fill(.ultraThinMaterial))
                            .shadow(radius: 2)

                        VStack(alignment: .leading, spacing: 4) {
                            Text("KUTTΣR THORNTON")
                                .font(.title2.bold())
                            Text("@kutter_thornton")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 8)
                } header: {
                    Text("Account")
                }

                Section {
                    if isLoading {
                        HStack {
                            ProgressView()
                            Text("Loading bars...")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 6)
                    } else if displayedBars.isEmpty {
                        ContentUnavailableView(
                            "No Bars Yet",
                            systemImage: "mappin.slash.circle",
                            description: Text("Bars from Supabase will appear here once loaded.")
                        )
                    } else {
                        ForEach(displayedBars) { bar in
                            HStack(spacing: 14) {
                                Image(systemName: "mappin.circle.fill")
                                    .font(.title3)
                                    .foregroundStyle(bar.hypeColor)

                                VStack(alignment: .leading, spacing: 3) {
                                    Text(bar.name)
                                        .font(.headline)

                                    if !bar.address.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                        Text(bar.address)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }

                                Spacer()

                                VStack(alignment: .trailing, spacing: 2) {
                                    Text("Hype \(bar.hype_score)/10")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    Text("\(bar.people_count) ppl")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .padding(.vertical, 2)
                        }

                        if hasMoreToShow || showAllBars {
                            Button {
                                withAnimation {
                                    showAllBars.toggle()
                                }
                            } label: {
                                HStack {
                                    Spacer()
                                    Text(showAllBars ? "Show Less" : "Show More (\(filteredBars.count - 10) more)")
                                        .font(.subheadline)
                                        .foregroundStyle(.blue)
                                    Spacer()
                                }
                                .padding(.vertical, 8)
                            }
                        }
                    }
                } header: {
                    HStack {
                        Text("Bar List")
                        Spacer()
                        Text("\(filteredBars.count) total")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } footer: {
                    if let errorMessage {
                        Text(errorMessage)
                            .font(.caption2)
                            .foregroundStyle(.red)
                    }
                }

                Section("Preferences") {
                    Toggle("Dark Mode", isOn: $isDarkMode)
                    Toggle("Push Notifications", isOn: $enableNotifications)

                    Picker("Show hype markers ≥", selection: $minHypeToShow) {
                        Text("All").tag(0)
                        Text("5+").tag(5)
                        Text("8+").tag(8)
                    }
                    .pickerStyle(.segmented)
                }

                Section {
                    Button(role: .destructive) {
                        showingClearConfirmation = true
                    } label: {
                        Label("Clear Cached Bars", systemImage: "trash")
                    }
                }
            }
            .navigationTitle("Account")
            .navigationBarTitleDisplayMode(.inline)
            .confirmationDialog(
                "Clear Cached Bars?",
                isPresented: $showingClearConfirmation
            ) {
                Button("Clear", role: .destructive) {
                    bars.removeAll()
                    showAllBars = false
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("This only clears the local list. It won’t delete data in Supabase.")
            }
            .task {
                await loadBars()
            }
        }
    }

    private func loadBars() async {
        isLoading = true
        defer { isLoading = false }

        do {
            let fetchedBars: [Bars] = try await supabase
                .from("bars")
                .select()
                .order("hype_score", ascending: false)
                .execute()
                .value

            await MainActor.run {
                bars = fetchedBars
                errorMessage = nil
            }
        } catch {
            await MainActor.run {
                errorMessage = "Failed to load bars: \(error.localizedDescription)"
            }
        }
    }
}

#Preview {
    AccountView()
}
