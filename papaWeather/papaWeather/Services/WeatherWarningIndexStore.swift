//
//  WeatherWarningIndexStore.swift
//  papaWeather
//

import CoreLocation
import Foundation

/// The small, app-group-backed snapshot used by Spotlight and App Intents.
/// It deliberately contains only the warning list and the coordinate used for
/// the fetch; full warning detail remains fetched from BOM on demand in-app.
struct WeatherWarningIndexSnapshot: Codable, Sendable {
    let warnings: [WeatherWarningInfo]
    let updatedAt: Date
    let latitude: Double?
    let longitude: Double?
}

enum WeatherWarningIndexStore {
    private static let storageKey = "papaWeather.weatherWarningIndex"

    static func save(_ warnings: [WeatherWarningInfo], for coordinate: CLLocationCoordinate2D) {
        let snapshot = WeatherWarningIndexSnapshot(
            warnings: warnings,
            updatedAt: .now,
            latitude: coordinate.latitude,
            longitude: coordinate.longitude
        )

        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        SharedAppStorage.defaults.set(data, forKey: storageKey)
    }

    static func load() -> WeatherWarningIndexSnapshot? {
        guard let data = SharedAppStorage.defaults.data(forKey: storageKey) else {
            return nil
        }

        return try? JSONDecoder().decode(WeatherWarningIndexSnapshot.self, from: data)
    }
}
