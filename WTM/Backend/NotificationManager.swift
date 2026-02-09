import Foundation
import UserNotifications

struct NotificationPreferences {
    let masterEnabled: Bool
    let weekendPromptsEnabled: Bool
    let newEventsEnabled: Bool
    let eventChatsEnabled: Bool
}

final class NotificationManager {
    static let shared = NotificationManager()

    private let center: UNUserNotificationCenter
    private let defaults: UserDefaults

    private let fridayPromptID = "wtm.weekend.friday.22"
    private let saturdayPromptID = "wtm.weekend.saturday.22"
    private let chatReminderPrefix = "wtm.event-chat."

    private let seenEventIDsKey = "wtm.notification.seen_event_ids"
    private let seenEventIDsInitializedKey = "wtm.notification.seen_event_ids_initialized"

    private let localDateParser: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone.current
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    private let localTimeParser: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone.current
        formatter.dateFormat = "HH:mm:ss"
        return formatter
    }()

    private init(
        center: UNUserNotificationCenter = .current(),
        defaults: UserDefaults = .standard
    ) {
        self.center = center
        self.defaults = defaults
    }

    func configure() {
        center.delegate = WTMNotificationDelegate.shared
    }

    func requestAuthorizationIfNeeded() async -> Bool {
        let settings = await notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return true
        case .denied:
            return false
        case .notDetermined:
            return await requestAuthorization()
        @unknown default:
            return false
        }
    }

    func syncScheduledNotifications(preferences: NotificationPreferences, goingEvents: [Event]) async {
        guard preferences.masterEnabled else {
            await clearManagedNotifications()
            return
        }

        guard await isAuthorizedForAlerts() else {
            return
        }

        if preferences.weekendPromptsEnabled {
            await scheduleWeekendPrompts()
        } else {
            center.removePendingNotificationRequests(withIdentifiers: [fridayPromptID, saturdayPromptID])
        }

        if preferences.eventChatsEnabled {
            await syncGoingEventChatReminders(for: goingEvents)
        } else {
            await clearEventChatReminders()
        }
    }

    func scheduleGoingStateNotification(for event: Event, isGoing: Bool, preferences: NotificationPreferences) async {
        let reminderID = chatReminderIdentifier(for: event.id)

        guard preferences.masterEnabled, preferences.eventChatsEnabled else {
            center.removePendingNotificationRequests(withIdentifiers: [reminderID])
            return
        }

        guard await isAuthorizedForAlerts() else {
            return
        }

        if isGoing {
            await scheduleImmediateEventChatAddedNotification(for: event)
            await scheduleEventChatReminder(for: event)
        } else {
            center.removePendingNotificationRequests(withIdentifiers: [reminderID])
        }
    }

    func notifyForNewEventsIfNeeded(currentEvents: [Event], preferences: NotificationPreferences) async {
        let currentIDs = Set(currentEvents.map(\.id))

        guard defaults.bool(forKey: seenEventIDsInitializedKey) else {
            storeSeenEventIDs(currentIDs)
            defaults.set(true, forKey: seenEventIDsInitializedKey)
            return
        }

        let seenIDs = loadSeenEventIDs()
        let newEvents = currentEvents.filter { !seenIDs.contains($0.id) }
        storeSeenEventIDs(seenIDs.union(currentIDs))

        guard preferences.masterEnabled, preferences.newEventsEnabled else { return }
        guard !newEvents.isEmpty else { return }
        guard await isAuthorizedForAlerts() else { return }

        for event in newEvents.prefix(4) {
            await scheduleImmediateNewEventNotification(for: event)
        }
    }

    func markEventAsSeen(_ eventID: Int) {
        var seen = loadSeenEventIDs()
        seen.insert(eventID)
        storeSeenEventIDs(seen)
        defaults.set(true, forKey: seenEventIDsInitializedKey)
    }

    func sendDebugTestNotification() async -> Bool {
        let authorized = await isAuthorizedForAlerts()
        let requested = await requestAuthorizationIfNeeded()
        guard authorized || requested else {
            return false
        }

        let content = UNMutableNotificationContent()
        content.title = "WTM Test Notification"
        content.body = "Notifications are working."
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "wtm.debug.test.\(Int(Date().timeIntervalSince1970))",
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        )
        await add(request: request)
        return true
    }

    private func scheduleWeekendPrompts() async {
        let fridayContent = UNMutableNotificationContent()
        fridayContent.title = "Friday night plans?"
        fridayContent.body = "Open WTM and start a party. More people are heading out now."
        fridayContent.sound = .default

        var fridayComponents = DateComponents()
        fridayComponents.weekday = 6
        fridayComponents.hour = 22
        fridayComponents.minute = 0

        let fridayTrigger = UNCalendarNotificationTrigger(dateMatching: fridayComponents, repeats: true)
        let fridayRequest = UNNotificationRequest(identifier: fridayPromptID, content: fridayContent, trigger: fridayTrigger)

        let saturdayContent = UNMutableNotificationContent()
        saturdayContent.title = "Saturday night is live"
        saturdayContent.body = "Check what's popping nearby and invite your people out."
        saturdayContent.sound = .default

        var saturdayComponents = DateComponents()
        saturdayComponents.weekday = 7
        saturdayComponents.hour = 22
        saturdayComponents.minute = 0

        let saturdayTrigger = UNCalendarNotificationTrigger(dateMatching: saturdayComponents, repeats: true)
        let saturdayRequest = UNNotificationRequest(identifier: saturdayPromptID, content: saturdayContent, trigger: saturdayTrigger)

        await add(request: fridayRequest)
        await add(request: saturdayRequest)
    }

    private func syncGoingEventChatReminders(for events: [Event]) async {
        let allowedIDs = Set(events.map { chatReminderIdentifier(for: $0.id) })
        let pending = await pendingRequestIDs()
        let stale = pending.filter { $0.hasPrefix(chatReminderPrefix) && !allowedIDs.contains($0) }
        if !stale.isEmpty {
            center.removePendingNotificationRequests(withIdentifiers: stale)
        }

        for event in events {
            await scheduleEventChatReminder(for: event)
        }
    }

    private func scheduleEventChatReminder(for event: Event) async {
        let identifier = chatReminderIdentifier(for: event.id)
        center.removePendingNotificationRequests(withIdentifiers: [identifier])

        guard let reminderDate = chatReminderDate(for: event) else {
            return
        }

        let content = UNMutableNotificationContent()
        content.title = "Event chat is heating up"
        content.body = "\(event.name) starts soon. Jump into chat and coordinate."
        content.sound = .default

        let dateComponents = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute],
            from: reminderDate
        )
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: false)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        await add(request: request)
    }

    private func scheduleImmediateEventChatAddedNotification(for event: Event) async {
        let content = UNMutableNotificationContent()
        content.title = "Event chat added"
        content.body = "You're going to \(event.name). Its chat is now in your Chats tab."
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "wtm.event-chat-added.\(event.id).\(Int(Date().timeIntervalSince1970))",
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        )
        await add(request: request)
    }

    private func scheduleImmediateNewEventNotification(for event: Event) async {
        let content = UNMutableNotificationContent()
        content.title = "New event posted"
        content.body = "\(event.name) at \(event.location)"
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "wtm.new-event.\(event.id).\(Int(Date().timeIntervalSince1970))",
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        )
        await add(request: request)
    }

    private func clearManagedNotifications() async {
        let pending = await pendingRequestIDs()
        let managed = pending.filter {
            $0 == fridayPromptID ||
            $0 == saturdayPromptID ||
            $0.hasPrefix(chatReminderPrefix)
        }

        if !managed.isEmpty {
            center.removePendingNotificationRequests(withIdentifiers: managed)
        }
    }

    private func clearEventChatReminders() async {
        let pending = await pendingRequestIDs()
        let managed = pending.filter { $0.hasPrefix(chatReminderPrefix) }
        if !managed.isEmpty {
            center.removePendingNotificationRequests(withIdentifiers: managed)
        }
    }

    private func chatReminderDate(for event: Event) -> Date? {
        guard let eventDate = localDateParser.date(from: event.date),
              let startTime = event.start_time,
              let parsedStart = localTimeParser.date(from: startTime) else {
            return nil
        }

        let calendar = Calendar.current
        let timeComponents = calendar.dateComponents([.hour, .minute, .second], from: parsedStart)
        var eventComponents = calendar.dateComponents([.year, .month, .day], from: eventDate)
        eventComponents.hour = timeComponents.hour
        eventComponents.minute = timeComponents.minute
        eventComponents.second = timeComponents.second

        guard let eventStartDate = calendar.date(from: eventComponents) else {
            return nil
        }

        let reminder = eventStartDate.addingTimeInterval(-30 * 60)
        if reminder <= Date().addingTimeInterval(15) {
            return nil
        }
        return reminder
    }

    private func chatReminderIdentifier(for eventID: Int) -> String {
        "\(chatReminderPrefix)\(eventID)"
    }

    private func isAuthorizedForAlerts() async -> Bool {
        let settings = await notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return settings.alertSetting == .enabled
        default:
            return false
        }
    }

    private func requestAuthorization() async -> Bool {
        await withCheckedContinuation { continuation in
            center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
                continuation.resume(returning: granted)
            }
        }
    }

    private func notificationSettings() async -> UNNotificationSettings {
        await withCheckedContinuation { continuation in
            center.getNotificationSettings { settings in
                continuation.resume(returning: settings)
            }
        }
    }

    private func pendingRequestIDs() async -> [String] {
        await withCheckedContinuation { continuation in
            center.getPendingNotificationRequests { requests in
                continuation.resume(returning: requests.map(\.identifier))
            }
        }
    }

    private func add(request: UNNotificationRequest) async {
        await withCheckedContinuation { continuation in
            center.add(request) { _ in
                continuation.resume(returning: ())
            }
        }
    }

    private func loadSeenEventIDs() -> Set<Int> {
        let raw = defaults.array(forKey: seenEventIDsKey) as? [Int] ?? []
        return Set(raw)
    }

    private func storeSeenEventIDs(_ ids: Set<Int>) {
        defaults.set(Array(ids), forKey: seenEventIDsKey)
    }
}

final class WTMNotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    static let shared = WTMNotificationDelegate()

    private override init() {
        super.init()
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound, .list])
    }
}
