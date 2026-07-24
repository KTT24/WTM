//
//  WTMApp.swift
//  WTM
//

import SwiftUI
import SwiftData


@main
struct WTMApp: App {
    @Environment(\.scenePhase) private var scenePhase

    @StateObject private var eventPredictionCoordinator = EventPredictionCoordinator()
    @StateObject private var appDataStore = AppDataStore()
    @State private var showSuggestedEvent = false

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(eventPredictionCoordinator)
                .environmentObject(appDataStore)
                .partySuggestionAlert(using: eventPredictionCoordinator)
                .fullScreenCover(isPresented: $showSuggestedEvent) {
                    AddEventView()
                }
                .onChange(of: scenePhase) { phase in
                    eventPredictionCoordinator.setAppActive(phase == .active)
                }
        }
    }
}
