//
//  DebugLocationStore.swift
//  WTM
//

import Foundation
import CoreLocation

enum DebugLocationStore {
    static let notification = Notification.Name("wtm.debug_location_changed")
    private static let latKey = "debug_location_lat"
    private static let lonKey = "debug_location_lon"

    static func currentOverride() -> CLLocation? {
        let defaults = UserDefaults.standard
        guard defaults.object(forKey: latKey) != nil,
              defaults.object(forKey: lonKey) != nil
        else { return nil }

        let lat = defaults.double(forKey: latKey)
        let lon = defaults.double(forKey: lonKey)
        return CLLocation(latitude: lat, longitude: lon)
    }

    static func setOverride(latitude: Double, longitude: Double) {
        let defaults = UserDefaults.standard
        defaults.set(latitude, forKey: latKey)
        defaults.set(longitude, forKey: lonKey)
        NotificationCenter.default.post(name: notification, object: nil)
    }

    static func clearOverride() {
        let defaults = UserDefaults.standard
        defaults.removeObject(forKey: latKey)
        defaults.removeObject(forKey: lonKey)
        NotificationCenter.default.post(name: notification, object: nil)
    }
}
