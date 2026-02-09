import SwiftUI

struct PartySuggestionAlertModifier: ViewModifier {
    @ObservedObject var coordinator: EventPredictionCoordinator

    func body(content: Content) -> some View {
        let isPresented = Binding(
            get: { coordinator.activeSuggestion != nil },
            set: { newValue in
                if !newValue {
                    coordinator.dismissSuggestion()
                }
            }
        )

        return content.alert(
            "Make this a party?",
            isPresented: isPresented
        ) {
            Button("Create Event") {
                coordinator.acceptSuggestion()
            }
            Button("Private Party") {
                coordinator.markPrivateParty()
            }
            Button("Not Now", role: .cancel) {
                coordinator.dismissSuggestion()
            }
        } message: {
            if let suggestion = coordinator.activeSuggestion {
                Text("You and at least \(suggestion.participantCount) people are nearby. Want to make an event?")
            } else {
                Text("You and others are nearby. Want to make an event?")
            }
        }
    }
}

extension View {
    func partySuggestionAlert(using coordinator: EventPredictionCoordinator) -> some View {
        modifier(PartySuggestionAlertModifier(coordinator: coordinator))
    }
}
