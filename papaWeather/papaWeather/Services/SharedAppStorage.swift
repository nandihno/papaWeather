//
//  SharedAppStorage.swift
//  papaWeather
//

import Foundation

/// User defaults shared by the app and future system-facing targets.
///
/// The migration keeps data written by older app versions available after the
/// App Group is introduced. A fallback to standard defaults keeps local debug
/// builds usable if the App Group entitlement is not provisioned yet.
enum SharedAppStorage {
    static let appGroupIdentifier = "group.org.nando.papaWeather"

    static let defaults: UserDefaults = {
        guard let sharedDefaults = UserDefaults(suiteName: appGroupIdentifier) else {
            return .standard
        }

        migrate(key: "papaWeather.savedLocations", from: .standard, to: sharedDefaults)
        migrate(key: "papaWeather.activeLocationID", from: .standard, to: sharedDefaults)
        migrate(key: "papaWeather.customWeatherStations", from: .standard, to: sharedDefaults)
        return sharedDefaults
    }()

    private static func migrate(key: String, from source: UserDefaults, to destination: UserDefaults) {
        guard destination.object(forKey: key) == nil,
              let value = source.object(forKey: key) else {
            return
        }

        destination.set(value, forKey: key)
    }
}
