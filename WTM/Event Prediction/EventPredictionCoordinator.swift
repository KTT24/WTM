import Foundation
import Combine

@MainActor
final class EventPredictionCoordinator: ObservableObject {
    @Published private(set) var activeSuggestion: PartySuggestion?

    var onCreateEvent: ((PartySuggestion) -> Void)?

    private let settings: EventPredictionSettings
    private let tokenProvider: PresenceTokenProvider
    private let presenceManager: NearbyPresenceManager
    private let uploader: PresenceUploader
    private let api: PresenceAPI
    private let suggestionService: PartySuggestionService

    private var suggestionTimer: Timer?
    private var tokenTimer: Timer?
    private var isAppActive = true
    private var cancellables: Set<AnyCancellable> = []

    init(
        settings: EventPredictionSettings = .shared,
        tokenProvider: PresenceTokenProvider = PresenceTokenProvider(),
        api: PresenceAPI = PresenceAPI(),
        suggestionService: PartySuggestionService = PartySuggestionService()
    ) {
        self.settings = settings
        self.tokenProvider = tokenProvider
        self.api = api
        self.suggestionService = suggestionService

        self.presenceManager = NearbyPresenceManager(tokenProvider: tokenProvider)
        self.uploader = PresenceUploader(api: api)

        presenceManager.onSighting = { [weak self] sighting in
            self?.uploader.enqueue(sighting)
        }

        settings.$isDiscoverable
            .sink { [weak self] isEnabled in
                _ = isEnabled
                self?.updatePresenceState()
            }
            .store(in: &cancellables)

        settings.$allowBackgroundDetection
            .sink { [weak self] _ in
                self?.updatePresenceState()
            }
            .store(in: &cancellables)

        settings.$suggestionsEnabled
            .sink { [weak self] _ in
                self?.refreshSuggestionIfNeeded()
            }
            .store(in: &cancellables)
    }

    func start() {
        updatePresenceState()
    }

    func stop() {
        presenceManager.stop()
        uploader.stop()
        stopTimers()
        activeSuggestion = nil
    }

    func setAppActive(_ isActive: Bool) {
        isAppActive = isActive
        updatePresenceState()
    }

    func acceptSuggestion() {
        guard let suggestion = activeSuggestion else { return }
        Task {
            try? await suggestionService.updateStatus(id: suggestion.id, status: .accepted)
        }
        activeSuggestion = nil
        settings.suppressSuggestions(for: EventPredictionConstants.suggestionCooldownSeconds)
        onCreateEvent?(suggestion)
    }

    func markPrivateParty() {
        guard let suggestion = activeSuggestion else { return }
        Task {
            try? await suggestionService.updateStatus(id: suggestion.id, status: .privateParty)
        }
        activeSuggestion = nil
        settings.suppressSuggestions(for: EventPredictionConstants.suggestionCooldownSeconds)
    }

    func dismissSuggestion() {
        guard let suggestion = activeSuggestion else { return }
        Task {
            try? await suggestionService.updateStatus(id: suggestion.id, status: .dismissed)
        }
        activeSuggestion = nil
        settings.suppressSuggestions(for: EventPredictionConstants.suggestionCooldownSeconds)
    }

    func injectDebugSuggestion(participantCount: Int = Int.random(in: 6...18)) {
        let suggestion = PartySuggestion(
            id: UUID(),
            groupId: UUID(),
            participantCount: participantCount,
            suggestedAt: Date(),
            status: .pending
        )
        activeSuggestion = suggestion
    }

    private func updatePresenceState() {
        if shouldRunPresence {
            presenceManager.start()
            uploader.start()
            registerCurrentToken()
            startTimers()
        } else {
            presenceManager.stop()
            uploader.stop()
            stopTimers()
            if !settings.isDiscoverable {
                activeSuggestion = nil
            }
        }
    }

    private func startTimers() {
        stopTimers()
        tokenTimer = Timer.scheduledTimer(withTimeInterval: EventPredictionConstants.tokenRotationSeconds, repeats: true) { [weak self] _ in
            self?.registerCurrentToken()
        }
        suggestionTimer = Timer.scheduledTimer(withTimeInterval: EventPredictionConstants.suggestionPollSeconds, repeats: true) { [weak self] _ in
            self?.refreshSuggestionIfNeeded()
        }
    }

    private func stopTimers() {
        suggestionTimer?.invalidate()
        suggestionTimer = nil
        tokenTimer?.invalidate()
        tokenTimer = nil
    }

    private func registerCurrentToken() {
        guard settings.isDiscoverable else { return }
        let token = tokenProvider.currentToken()
        Task {
            do {
                try await api.registerToken(token)
            } catch {
                print("Token registration failed:", error.localizedDescription)
            }
        }
    }

    private func refreshSuggestionIfNeeded() {
        guard settings.isDiscoverable else { return }
        guard settings.suggestionsEnabled else { return }
        guard shouldRunPresence else { return }
        guard !settings.isInCooldown else { return }
        guard activeSuggestion == nil else { return }

        Task {
            do {
                if let suggestion = try await suggestionService.fetchPendingSuggestion() {
                    activeSuggestion = suggestion
                }
            } catch {
                print("Suggestion fetch failed:", error.localizedDescription)
            }
        }
    }

    private var shouldRunPresence: Bool {
        settings.isDiscoverable && (settings.allowBackgroundDetection || isAppActive)
    }
}
