//
//  WeatherIntents.swift
//  papaWeatherIntents
//

import AppIntents
import CoreLocation
import Foundation

// MARK: - Intent support

enum WeatherIntentError: LocalizedError, Sendable {
    case conditionsUnavailable
    case forecastUnavailable
    case warningsUnavailable
    case invalidForecastOffset

    var errorDescription: String? {
        switch self {
        case .conditionsUnavailable:
            return "Current weather conditions are unavailable."
        case .forecastUnavailable:
            return "The BOM forecast is unavailable for that location."
        case .warningsUnavailable:
            return "Current BOM warnings could not be checked."
        case .invalidForecastOffset:
            return "Choose a forecast day from today through six days from now."
        }
    }
}

@MainActor
private enum WeatherIntentSupport {
    static func fetchBundle(for location: WeatherLocationEntity?) async throws -> WeatherService.WeatherBundle {
        let bundle: WeatherService.WeatherBundle

        if let location, let coordinate = location.coordinate {
            bundle = try await WeatherService.shared.fetchWeatherBundle(
                coordinate: CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude),
                presetLocalityName: location.name
            )
        } else {
            bundle = try await WeatherService.shared.fetchWeatherBundle()
        }

        // Keep the Spotlight index current when a system surface fetches data
        // directly instead of going through WeatherView.
        if bundle.warnings != nil {
            WeatherWarningSpotlightIndexer.refreshInBackground()
        }

        return bundle
    }

    static func currentConditionsDialog(for location: WeatherLocationEntity?) async throws -> IntentDialog {
        let bundle = try await fetchBundle(for: location)
        guard let current = bundle.weather.latest else {
            throw WeatherIntentError.conditionsUnavailable
        }

        let place = bundle.locality ?? location?.name ?? "your location"
        var details = [
            "\(format(current.airTemp)) degrees Celsius",
            "feels like \(format(current.apparentTemp)) degrees"
        ]

        if !current.cloud.isEmpty {
            details.append(current.cloud.lowercased())
        }
        if current.windSpeedKmh > 0 {
            details.append("\(current.windDir) wind at \(current.windSpeedKmh) kilometres per hour")
        }

        return IntentDialog(stringLiteral: "\(place): \(details.joined(separator: ", ")).")
    }

    static func forecastDialog(
        for location: WeatherLocationEntity?,
        dayOffset: Int
    ) async throws -> IntentDialog {
        guard (0...6).contains(dayOffset) else {
            throw WeatherIntentError.invalidForecastOffset
        }

        let bundle = try await fetchBundle(for: location)
        guard let forecast = bundle.forecast,
              forecast.days.indices.contains(dayOffset) else {
            throw WeatherIntentError.forecastUnavailable
        }

        let day = forecast.days[dayOffset]
        let place = bundle.locality ?? location?.name ?? forecast.locationName
        var details = [day.date]

        if let tempMin = day.tempMin, let tempMax = day.tempMax {
            details.append("low \(tempMin) and high \(tempMax) degrees Celsius")
        } else if let tempMax = day.tempMax {
            details.append("high \(tempMax) degrees Celsius")
        }

        if let shortText = day.shortText?.trimmingCharacters(in: .whitespacesAndNewlines),
           !shortText.isEmpty {
            details.append(shortText)
        } else if let extendedText = day.extendedText?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !extendedText.isEmpty {
            details.append(extendedText)
        }

        if let rainChance = day.rainChancePercent {
            details.append("rain chance \(rainChance) percent")
        }

        return IntentDialog(stringLiteral: "\(place) forecast: \(details.joined(separator: ", ")).")
    }

    static func warningsResult(
        for location: WeatherLocationEntity?
    ) async throws -> (entities: [WeatherWarningEntity], dialog: IntentDialog) {
        let bundle = try await fetchBundle(for: location)
        guard let warnings = bundle.warnings else {
            throw WeatherIntentError.warningsUnavailable
        }

        let entities = warnings.map {
            WeatherWarningEntity(
                warning: $0,
                indexedAt: .now,
                latitude: location?.latitude,
                longitude: location?.longitude
            )
        }
        let place = bundle.locality ?? location?.name ?? "your location"

        if warnings.isEmpty {
            return (
                entities,
                IntentDialog(stringLiteral: "There are no current BOM weather warnings for \(place).")
            )
        }

        let names = warnings.prefix(3).map(\.title).joined(separator: "; ")
        let suffix = warnings.count > 3 ? " and \(warnings.count - 3) more" : ""
        let warningWord = warnings.count == 1 ? "warning" : "warnings"
        return (
            entities,
            IntentDialog(stringLiteral: "There are \(warnings.count) current BOM \(warningWord) for \(place): \(names)\(suffix).")
        )
    }

    private static func format(_ value: Double) -> String {
        String(format: "%.1f", value)
    }
}

/// Donations are best-effort. They improve Siri/Shortcuts prediction without
/// turning a successful weather response into a failure if the donation store
/// is temporarily unavailable.
private enum WeatherIntentDonation {
    static func donate<Intent: AppIntent>(_ intent: Intent) async {
        _ = try? await IntentDonationManager.shared.donate(intent: intent)
    }

    static func donate<Intent: AppIntent, Result: IntentResult>(
        _ intent: Intent,
        result: Result
    ) async {
        _ = try? await IntentDonationManager.shared.donate(intent: intent, result: result)
    }
}

// MARK: - Read intents

struct GetCurrentConditionsIntent: LongRunningIntent {
    static let title: LocalizedStringResource = "Get Current Conditions"
    static let description = IntentDescription(
        "Get the latest Bureau of Meteorology conditions for a location."
    )

    /// Keep execution in the App Intents extension so Siri and Shortcuts do
    /// not need to cold-launch the main UI process.
    static var allowedExecutionTargets: IntentExecutionTargets { .appIntentsExtension }

    @Parameter(title: "Location")
    var location: WeatherLocationEntity?

    static var parameterSummary: some ParameterSummary {
        Summary("Get current conditions for \(\.$location)")
    }

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let intentProgress = progress
        intentProgress.totalUnitCount = 1
        intentProgress.completedUnitCount = 0
        defer { intentProgress.completedUnitCount = intentProgress.totalUnitCount }

        let requestedLocation = location
        let dialog = try await performBackgroundTask { [requestedLocation] in
            try await WeatherIntentSupport.currentConditionsDialog(for: requestedLocation)
        }
        let result: IntentResultContainer<Never, Never, Never, IntentDialog> =
            .result(dialog: dialog)
        await WeatherIntentDonation.donate(self, result: result)
        return result
    }
}

struct GetForecastIntent: LongRunningIntent {
    static let title: LocalizedStringResource = "Get Weather Forecast"
    static let description = IntentDescription(
        "Get the Bureau of Meteorology forecast for a location."
    )

    static var allowedExecutionTargets: IntentExecutionTargets { .appIntentsExtension }

    @Parameter(title: "Location")
    var location: WeatherLocationEntity?

    @Parameter(title: "Days from now", default: 0)
    var dayOffset: Int

    static var parameterSummary: some ParameterSummary {
        Summary("Get the forecast for \(\.$location)") {
            \.$dayOffset
        }
    }

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let intentProgress = progress
        intentProgress.totalUnitCount = 1
        intentProgress.completedUnitCount = 0
        defer { intentProgress.completedUnitCount = intentProgress.totalUnitCount }

        let requestedLocation = location
        let requestedDayOffset = dayOffset
        let dialog = try await performBackgroundTask {
            try await WeatherIntentSupport.forecastDialog(
                for: requestedLocation,
                dayOffset: requestedDayOffset
            )
        }
        let result: IntentResultContainer<Never, Never, Never, IntentDialog> =
            .result(dialog: dialog)
        await WeatherIntentDonation.donate(self, result: result)
        return result
    }
}

struct GetWarningsIntent: LongRunningIntent {
    static let title: LocalizedStringResource = "Get Weather Warnings"
    static let description = IntentDescription(
        "Check current Bureau of Meteorology warnings for a location."
    )

    static var allowedExecutionTargets: IntentExecutionTargets { .appIntentsExtension }

    @Parameter(title: "Location")
    var location: WeatherLocationEntity?

    static var parameterSummary: some ParameterSummary {
        Summary("Get weather warnings for \(\.$location)")
    }

    func perform() async throws -> some IntentResult & ReturnsValue<[WeatherWarningEntity]> & ProvidesDialog {
        let intentProgress = progress
        intentProgress.totalUnitCount = 1
        intentProgress.completedUnitCount = 0
        defer { intentProgress.completedUnitCount = intentProgress.totalUnitCount }

        let requestedLocation = location
        let weatherResult = try await performBackgroundTask { [requestedLocation] in
            try await WeatherIntentSupport.warningsResult(for: requestedLocation)
        }
        let result: IntentResultContainer<[WeatherWarningEntity], Never, Never, IntentDialog> =
            .result(value: weatherResult.entities, dialog: weatherResult.dialog)
        await WeatherIntentDonation.donate(self, result: result)
        return result
    }
}

// MARK: - App Shortcuts

struct PapaWeatherAppShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: GetCurrentConditionsIntent(),
            phrases: [
                "Get current conditions in \(.applicationName)",
                "What's the weather in \(.applicationName)"
            ],
            shortTitle: "Current Conditions",
            systemImageName: "thermometer.medium"
        )
        AppShortcut(
            intent: GetForecastIntent(),
            phrases: [
                "Get the forecast in \(.applicationName)",
                "What's the forecast in \(.applicationName)"
            ],
            shortTitle: "Weather Forecast",
            systemImageName: "calendar"
        )
        AppShortcut(
            intent: GetWarningsIntent(),
            phrases: [
                "Check weather warnings in \(.applicationName)",
                "Are there weather warnings in \(.applicationName)"
            ],
            shortTitle: "Weather Warnings",
            systemImageName: "exclamationmark.triangle.fill"
        )
    }

    static var shortcutTileColor: ShortcutTileColor = .lightBlue
}
