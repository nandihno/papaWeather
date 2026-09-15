//
//  WeatherEntities.swift
//  papaWeather
//

import AppIntents
import CoreLocation
import CoreTransferable
import Foundation
import UniformTypeIdentifiers

// MARK: - Weather location entity

/// The small system-facing representation of a location.
///
/// `SavedLocation` remains an app model. This shadow entity gives App Intents
/// a stable string identifier and a searchable display name without coupling
/// intent resolution to the app's view state.
struct WeatherLocationEntity: AppEntity, Sendable, Transferable {
    static let currentDeviceID = "current-device"
    static let defaultQuery = WeatherLocationEntityQuery()
    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Weather Location"

    let id: String

    @Property(title: "Name")
    var name: String

    @Property(title: "State")
    var state: String?

    let latitude: Double?
    let longitude: Double?

    var isCurrentDevice: Bool {
        id == Self.currentDeviceID
    }

    var coordinate: CLLocationCoordinate2D? {
        guard let latitude, let longitude else { return nil }
        return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    var displayRepresentation: DisplayRepresentation {
        let subtitle = state.flatMap { $0.isEmpty ? nil : $0 }
            ?? (isCurrentDevice ? "Device location" : "Saved location")
        return DisplayRepresentation(title: "\(name)", subtitle: "\(subtitle)")
    }

    /// Export a stable, JSON-compatible representation when another system
    /// surface needs to carry a resolved location beyond the intent call.
    static var transferRepresentation: some TransferRepresentation {
        ProxyRepresentation(exporting: { (location: WeatherLocationEntity) in
            location.transferPayload
        })
    }

    var transferPayload: WeatherLocationTransferPayload {
        WeatherLocationTransferPayload(
            id: id,
            name: name,
            state: state,
            latitude: latitude,
            longitude: longitude
        )
    }

    static let currentDevice = WeatherLocationEntity(
        id: currentDeviceID,
        name: "My Location",
        state: nil,
        latitude: nil,
        longitude: nil
    )

    init(
        id: String,
        name: String,
        state: String?,
        latitude: Double?,
        longitude: Double?
    ) {
        _name = EntityProperty(title: "Name")
        _state = EntityProperty(title: "State")
        self.id = id
        self.latitude = latitude
        self.longitude = longitude
        self.name = name
        self.state = state
    }

    init(savedLocation: SavedLocation) {
        self.init(
            id: savedLocation.id.uuidString,
            name: savedLocation.name,
            state: savedLocation.state,
            latitude: savedLocation.lat,
            longitude: savedLocation.lon
        )
    }
}

/// The cross-process payload for `WeatherLocationEntity`.
struct WeatherLocationTransferPayload: Codable, Sendable, Transferable {
    let id: String
    let name: String
    let state: String?
    let latitude: Double?
    let longitude: Double?

    static var transferRepresentation: some TransferRepresentation {
        CodableRepresentation(contentType: .json)
    }
}

/// Resolves both the device location and user-saved locations for Shortcuts
/// and Siri parameter pickers.
struct WeatherLocationEntityQuery: EntityStringQuery, Sendable {
    nonisolated func entities(for identifiers: [WeatherLocationEntity.ID]) async throws -> [WeatherLocationEntity] {
        let allLocations = await allLocations()
        let byID = Dictionary(uniqueKeysWithValues: allLocations.map { ($0.id, $0) })
        return identifiers.compactMap { byID[$0] }
    }

    nonisolated func entities(matching string: String) async throws -> [WeatherLocationEntity] {
        let allLocations = await allLocations()
        let query = string.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !query.isEmpty else { return allLocations }

        return allLocations.filter { location in
            location.name.localizedCaseInsensitiveContains(query)
                || location.state?.localizedCaseInsensitiveContains(query) == true
                || (location.isCurrentDevice && (
                    query.localizedCaseInsensitiveContains("current")
                        || query.localizedCaseInsensitiveContains("device")
                        || query.localizedCaseInsensitiveContains("my location")
                        || query.localizedCaseInsensitiveContains("near me")
                ))
        }
    }

    nonisolated func suggestedEntities() async throws -> [WeatherLocationEntity] {
        await allLocations()
    }

    private nonisolated func allLocations() async -> [WeatherLocationEntity] {
        let savedLocations = await MainActor.run {
            LocationSelectionStore.shared.saved.map(WeatherLocationEntity.init(savedLocation:))
        }
        return [WeatherLocationEntity.currentDevice] + savedLocations
    }
}
