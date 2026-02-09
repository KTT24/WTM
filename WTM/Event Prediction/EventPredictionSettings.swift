import Foundation
import Combine

final class EventPredictionSettings: ObservableObject {
    static let shared = EventPredictionSettings()

    @Published var isDiscoverable: Bool {
        didSet { defaults.set(isDiscoverable, forKey: Keys.isDiscoverable) }
    }

    @Published var allowBackgroundDetection: Bool {
        didSet { defaults.set(allowBackgroundDetection, forKey: Keys.allowBackgroundDetection) }
    }

    @Published var suggestionsEnabled: Bool {
        didSet { defaults.set(suggestionsEnabled, forKey: Keys.suggestionsEnabled) }
    }

    @Published var suggestionsSuppressedUntil: Date {
        didSet { defaults.set(suggestionsSuppressedUntil.timeIntervalSince1970, forKey: Keys.suggestionsSuppressedUntil) }
    }

    var isInCooldown: Bool {
        Date() < suggestionsSuppressedUntil
    }

    func suppressSuggestions(for seconds: TimeInterval) {
        suggestionsSuppressedUntil = Date().addingTimeInterval(seconds)
    }

    func clearSuggestionCooldown() {
        suggestionsSuppressedUntil = .distantPast
    }

    private let defaults: UserDefaults

    private init(defaults: UserDefaults = .standard) {
        self.defaults = defaults

        let suppressedTimestamp = defaults.double(forKey: Keys.suggestionsSuppressedUntil)

        self.isDiscoverable = defaults.bool(forKey: Keys.isDiscoverable)
        self.allowBackgroundDetection = defaults.object(forKey: Keys.allowBackgroundDetection) as? Bool ?? true
        self.suggestionsEnabled = defaults.object(forKey: Keys.suggestionsEnabled) as? Bool ?? true
        self.suggestionsSuppressedUntil = suppressedTimestamp > 0
            ? Date(timeIntervalSince1970: suppressedTimestamp)
            : .distantPast
    }

    private enum Keys {
        static let isDiscoverable = "event_prediction_discoverable"
        static let allowBackgroundDetection = "event_prediction_allow_background"
        static let suggestionsEnabled = "event_prediction_suggestions_enabled"
        static let suggestionsSuppressedUntil = "event_prediction_suggestions_suppressed_until"
    }
}
