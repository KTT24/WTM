//
//  Event.swift
//  WTM
//

import Foundation

struct Event: Identifiable, Decodable, Equatable {
    let id: Int
    let name: String
    let date: String
    let start_time: String?
    let end_time: String?
    let location: String
    let description: String

    var dateDisplay: String {
        if let parsed = WTMDateFormatters.eventDateParser.date(from: date) {
            return WTMDateFormatters.eventDateDisplay.string(from: parsed)
        }
        return date
    }

    var timeDisplay: String? {
        guard let start_time, !start_time.isEmpty else { return nil }

        let startDisplay = formatTime(start_time) ?? start_time
        let endDisplay = end_time.flatMap { formatTime($0) }

        if let endDisplay, !endDisplay.isEmpty {
            return "\(startDisplay) – \(endDisplay)"
        }
        return startDisplay
    }

    private func formatTime(_ value: String) -> String? {
        guard let date = WTMDateFormatters.timeOnly.date(from: value) else { return nil }
        return WTMDateFormatters.timeDisplay12.string(from: date)
    }
}
