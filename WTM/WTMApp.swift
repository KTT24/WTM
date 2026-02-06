//
//  WTMApp.swift
//  WTM
//

import SwiftUI
import SwiftData


@main
struct WTMApp: App {
    @AppStorage("isLoggedIn") private var isLoggedIn = false

    var body: some Scene {
        WindowGroup {
            if isLoggedIn {
                BarsMapView()
            } else {
                WelcomeScreen()
            }
        }
    }
}
