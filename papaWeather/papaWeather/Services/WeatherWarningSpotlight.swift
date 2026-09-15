//
//  WeatherWarningSpotlight.swift
//  papaWeather
//

import AppIntents
import CoreSpotlight
import CoreTransferable
import Foundation
import UniformTypeIdentifiers

/// A system-facing shadow model for BOM warnings.
///
/// The app model stays focused on rendering and BOM detail loading. This type
/// is intentionally narrower so App Intents and Spotlight can resolve a stable
/// identifier from the shared warning snapshot.
struct WeatherWarningEntity: IndexedEntity, Sendable, Transferable {
    private static let maxSpotlightAge: TimeInterval = 6 * 60 * 60

    static let defaultQuery = WeatherWarningEntityQuery()
    static let typeDisplayRepresentation: TypeDisplayRepresentation = "BOM Weather Warning"

    let id: String

    @Property(title: "Title", indexingKey: \.title)
    var title: String

    let subtitle: String
    let phenomena: String?
    let issueType: String?
    let typeCode: String
    let stateCode: String?
    let severityCodes: [String]
    let issuedAt: Date?
    let expiresAt: Date?
    let indexedAt: Date
    let latitude: Double?
    let longitude: Double?

    var isSevere: Bool {
        severityCodes.contains { $0.uppercased() != "STD" }
    }

    nonisolated var hideInSpotlight: Bool {
        Date.now.timeIntervalSince(indexedAt) > Self.maxSpotlightAge
    }

    @ComputedProperty(title: "Warning content", indexingKey: \.contentDescription)
    var searchableContent: String {
        [
            "Bureau of Meteorology weather warning",
            title,
            subtitle,
            phenomena,
            issueType,
            typeCode,
            stateCode,
            isSevere ? "Severe warning" : "Standard warning"
        ]
        .compactMap { $0 }
        .filter { !$0.isEmpty }
        .joined(separator: " ")
    }

    var displayRepresentation: DisplayRepresentation {
        let location = stateCode.map { "\($0)" }
        let severity = isSevere ? "Severe" : "Standard"
        let subtitle = [severity, location].compactMap { $0 }.joined(separator: " · ")
        return DisplayRepresentation(title: "\(title)", subtitle: "\(subtitle)")
    }

    /// Export the warning content as a compact JSON-compatible value so the
    /// entity can cross the App Intents/Shortcuts process boundary.
    static var transferRepresentation: some TransferRepresentation {
        ProxyRepresentation(exporting: { (warning: WeatherWarningEntity) in
            warning.transferPayload
        })
    }

    var transferPayload: WeatherWarningTransferPayload {
        WeatherWarningTransferPayload(
            id: id,
            title: title,
            subtitle: subtitle,
            phenomena: phenomena,
            issueType: issueType,
            typeCode: typeCode,
            stateCode: stateCode,
            severityCodes: severityCodes,
            issuedAt: issuedAt,
            expiresAt: expiresAt,
            latitude: latitude,
            longitude: longitude
        )
    }

    init(
        warning: WeatherWarningInfo,
        indexedAt: Date = .now,
        latitude: Double? = nil,
        longitude: Double? = nil
    ) {
        _title = EntityProperty(title: "Title", indexingKey: \.title)
        id = warning.id
        subtitle = warning.subtitle
        phenomena = warning.phenomena
        issueType = warning.issueType
        typeCode = warning.typeCode
        stateCode = warning.stateCode
        severityCodes = warning.severityCodes
        issuedAt = warning.issuedAt
        expiresAt = warning.expiresAt
        self.indexedAt = indexedAt
        self.latitude = latitude
        self.longitude = longitude
        title = warning.title
    }

    var attributeSet: CSSearchableItemAttributeSet {
        let attributes = defaultAttributeSet
        attributes.title = title
        attributes.contentDescription = searchableContent
        attributes.keywords = [
            "BOM",
            "weather warning",
            phenomena,
            issueType,
            typeCode,
            stateCode
        ].compactMap { $0 }.filter { !$0.isEmpty }

        if let latitude {
            attributes.latitude = NSNumber(value: latitude)
        }
        if let longitude {
            attributes.longitude = NSNumber(value: longitude)
        }

        // Severe warnings receive a stronger Spotlight ranking while every
        // item remains associated with this App Entity for system resolution.
        attributes.associateAppEntity(self, priority: isSevere ? 100 : 10)
        return attributes
    }
}

/// The cross-process payload for `WeatherWarningEntity`.
struct WeatherWarningTransferPayload: Codable, Sendable, Transferable {
    let id: String
    let title: String
    let subtitle: String
    let phenomena: String?
    let issueType: String?
    let typeCode: String
    let stateCode: String?
    let severityCodes: [String]
    let issuedAt: Date?
    let expiresAt: Date?
    let latitude: Double?
    let longitude: Double?

    static var transferRepresentation: some TransferRepresentation {
        CodableRepresentation(contentType: .json)
    }
}

struct WeatherWarningEntityQuery: EntityQuery, Sendable {
    nonisolated func entities(for identifiers: [WeatherWarningEntity.ID]) async throws -> [WeatherWarningEntity] {
        guard let snapshot = await MainActor.run(body: { WeatherWarningIndexStore.load() }) else { return [] }
        let requested = Set(identifiers)
        return activeWarnings(in: snapshot)
            .filter { requested.contains($0.id) }
            .map {
                WeatherWarningEntity(
                    warning: $0,
                    indexedAt: snapshot.updatedAt,
                    latitude: snapshot.latitude,
                    longitude: snapshot.longitude
                )
            }
    }

    nonisolated func suggestedEntities() async throws -> [WeatherWarningEntity] {
        guard let snapshot = await MainActor.run(body: { WeatherWarningIndexStore.load() }) else { return [] }
        return activeWarnings(in: snapshot)
            .sorted { lhs, rhs in
                if lhs.isSevere != rhs.isSevere { return lhs.isSevere }
                return (lhs.issuedAt ?? .distantPast) > (rhs.issuedAt ?? .distantPast)
            }
            .map {
                WeatherWarningEntity(
                    warning: $0,
                    indexedAt: snapshot.updatedAt,
                    latitude: snapshot.latitude,
                    longitude: snapshot.longitude
                )
            }
    }

    private nonisolated func activeWarnings(in snapshot: WeatherWarningIndexSnapshot) -> [WeatherWarningInfo] {
        guard Date.now.timeIntervalSince(snapshot.updatedAt) <= 6 * 60 * 60 else { return [] }

        return snapshot.warnings.filter { warning in
            warning.expiresAt.map { $0 > .now } ?? true
        }
    }
}

@available(iOS 27.0, *)
extension WeatherWarningEntityQuery: IndexedEntityQuery {
    private static let indexName = "papaWeather.weatherWarnings"

    func reindexEntities(
        for identifiers: [WeatherWarningEntity.ID],
        indexDescription: CSSearchableIndexDescription
    ) async throws {
        let entities = try await entities(for: identifiers)
        let index = CSSearchableIndex(
            name: Self.indexName,
            protectionClass: indexDescription.protectionClass
        )

        let resolvedIDs = Set(entities.map(\.id))
        let missingIDs = identifiers.filter { !resolvedIDs.contains($0) }
        if !missingIDs.isEmpty {
            try await index.deleteAppEntities(
                identifiedBy: missingIDs,
                ofType: WeatherWarningEntity.self
            )
        }
        if !entities.isEmpty {
            try await index.indexAppEntities(entities)
        }
    }

    func reindexAllEntities(indexDescription: CSSearchableIndexDescription) async throws {
        let entities = try await suggestedEntities()
        let index = CSSearchableIndex(
            name: Self.indexName,
            protectionClass: indexDescription.protectionClass
        )
        try await index.deleteAppEntities(ofType: WeatherWarningEntity.self)
        if !entities.isEmpty {
            try await index.indexAppEntities(entities)
        }
    }
}

/// Replaces the app's current BOM warning records in the system index.
///
/// The operation is deliberately best-effort: a Spotlight failure must never
/// make a weather refresh look like a network failure.
enum WeatherWarningSpotlightIndexer {
    /// Starts a best-effort refresh without making the caller wait for the
    /// system Spotlight service to respond.
    static func refreshInBackground() {
        Task.detached(priority: .utility) {
            await refresh()
        }
    }

    static func refresh() async {
        guard CSSearchableIndex.isIndexingAvailable() else { return }

        let entities = (try? await WeatherWarningEntityQuery().suggestedEntities()) ?? []

        do {
            let index = CSSearchableIndex.default()
            try await index.deleteAppEntities(ofType: WeatherWarningEntity.self)
            if !entities.isEmpty {
                try await index.indexAppEntities(entities)
            }
        } catch {
            print("⚠︎ Spotlight warning index refresh failed: \(error.localizedDescription)")
        }
    }
}
