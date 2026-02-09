//
//  WTMApp.swift
//  WTM
//

import SwiftUI
import SwiftData


@main
struct WTMApp: App {
    @AppStorage("isLoggedIn") private var isLoggedIn = false
    @Environment(\.scenePhase) private var scenePhase

    @StateObject private var eventPredictionCoordinator = EventPredictionCoordinator()
    @StateObject private var appDataStore = AppDataStore()
    @State private var showSuggestedEvent = false

    var body: some Scene {
        WindowGroup {
            Group {
                if isLoggedIn {
                    ContentView()
                } else {
                    WelcomeScreen()
                }
            }
            .environmentObject(eventPredictionCoordinator)
            .environmentObject(appDataStore)
            .partySuggestionAlert(using: eventPredictionCoordinator)
            .fullScreenCover(isPresented: $showSuggestedEvent) {
                AddEventView()
            }
            .onChange(of: scenePhase) { phase in
                eventPredictionCoordinator.setAppActive(phase == .active)
            }
            .onChange(of: isLoggedIn) { loggedIn in
                if loggedIn {
                    eventPredictionCoordinator.start()
                    Task { await appDataStore.preloadIfNeeded() }
                } else {
                    eventPredictionCoordinator.stop()
                }
            }
            .task {
                eventPredictionCoordinator.onCreateEvent = { _ in
                    showSuggestedEvent = true
                }

                if isLoggedIn {
                    eventPredictionCoordinator.start()
                    await appDataStore.preloadIfNeeded()
                }
            }
        }
    }
}
