//
//  SavedLocation.swift
//  papaWeather
//

import Foundation
import CoreLocation

// MARK: - Saved Location

/// A user-picked place (typically an Australian suburb) selected via MapKit search
/// in Settings. Only the resolved coordinate and a display name are persisted — the
/// coordinate is what drives every weather fetch.
struct SavedLocation: Identifiable, Codable, Equatable, Hashable {
    let id: UUID
    var name: String
    /// Optional AU state abbreviation (e.g. "VIC") shown as a chip in the list.
    var state: String?
    let lat: Double
    let lon: Double

    init(id: UUID = UUID(), name: String, state: String? = nil, lat: Double, lon: Double) {
        self.id    = id
        self.name  = name
        self.state = state
        self.lat   = lat
        self.lon   = lon
    }

    var coordinate: CLLocation {
        CLLocation(latitude: lat, longitude: lon)
    }
}

// MARK: - Active Location

/// The single source of truth for which location every tab is showing.
/// `.currentDevice` is the app's default and preserves the original GPS behaviour.
enum ActiveLocation: Equatable, Hashable {
    case currentDevice
    case saved(SavedLocation)

    var savedLocation: SavedLocation? {
        if case let .saved(location) = self { return location }
        return nil
    }
}
