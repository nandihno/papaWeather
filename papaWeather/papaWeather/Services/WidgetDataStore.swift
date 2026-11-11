//
//  WidgetDataStore.swift
//  papaWeather
//

import CoreLocation
import Foundation
import WidgetKit

// MARK: - Widget Models

struct WidgetHourlyItem: Identifiable, Codable, Sendable {
    let id: String
    let date: Date
    let time: String
    let temp: Int
    let feelsLike: Int
    let rainChance: Int
    let windSpeedKmh: Int
    let windDirection: String
    let symbolName: String
    let iconDescriptor: String
    let isNight: Bool
}

struct WidgetWeatherEntry: TimelineEntry, Codable, Sendable {
    let date: Date
    let locality: String
    let stationName: String
    let temp: Double
    let apparentTemp: Double
    let conditionText: String
    let symbolName: String
    let iconDescriptor: String
    let isNight: Bool
    let humidity: Int
    let windSpeedKmh: Int
    let windDirection: String
    let rainChance: Int
    let hourlyForecast: [WidgetHourlyItem]
    let isPlaceholder: Bool

    var rainOutlook: String {
        guard !hourlyForecast.isEmpty else {
            return "Hourly rain forecast unavailable"
        }

        let nextHours = Array(hourlyForecast.prefix(6))
        guard let wettest = nextHours.max(by: { $0.rainChance < $1.rainChance }) else {
            return "Low rain chance for next 6 hours"
        }

        switch wettest.rainChance {
        case 70...:
            return "Rain likely around \(wettest.time) (\(wettest.rainChance)%)"
        case 40...:
            return "Possible rain around \(wettest.time) (\(wettest.rainChance)%)"
        default:
            return "Low rain chance for next 6 hours"
        }
    }

    var peakWindOutlook: String {
        guard !hourlyForecast.isEmpty else {
            return "\(windDirection) \(windSpeedKmh) km/h"
        }

        let nextHours = Array(hourlyForecast.prefix(6))
        if let windiest = nextHours.max(by: { $0.windSpeedKmh < $1.windSpeedKmh }), windiest.windSpeedKmh > 0 {
            return "\(windiest.windDirection) up to \(windiest.windSpeedKmh) km/h"
        }
        return "\(windDirection) \(windSpeedKmh) km/h"
    }

    static func placeholder() -> WidgetWeatherEntry {
        WidgetWeatherEntry(
            date: .now,
            locality: "Melbourne",
            stationName: "Olympic Park",
            temp: 21.4,
            apparentTemp: 20.1,
            conditionText: "Partly Cloudy",
            symbolName: "cloud.sun.fill",
            iconDescriptor: "partly_cloudy",
            isNight: false,
            humidity: 62,
            windSpeedKmh: 19,
            windDirection: "SW",
            rainChance: 15,
            hourlyForecast: sampleHourly(),
            isPlaceholder: true
        )
    }

    static func sampleHourly() -> [WidgetHourlyItem] {
        let now = Date()
        let calendar = Calendar.current
        let formatter = DateFormatter()
        formatter.dateFormat = "ha"

        let temps = [21, 22, 23, 22, 20, 19, 18, 17]
        let rains = [10, 10, 20, 40, 65, 40, 20, 10]
        let icons = ["cloud.sun.fill", "sun.max.fill", "sun.max.fill", "cloud.sun.fill", "cloud.rain.fill", "cloud.rain.fill", "cloud.fill", "moon.stars.fill"]
        let descs = ["partly_cloudy", "sunny", "sunny", "partly_cloudy", "shower", "rain", "cloudy", "clear"]

        return (0..<8).map { i in
            let date = calendar.date(byAdding: .hour, value: i, to: now) ?? now
            let timeStr = i == 0 ? "Now" : formatter.string(from: date).lowercased()
            let isN = i >= 6

            return WidgetHourlyItem(
                id: "sample-\(i)",
                date: date,
                time: timeStr,
                temp: temps[i % temps.count],
                feelsLike: temps[i % temps.count] - 1,
                rainChance: rains[i % rains.count],
                windSpeedKmh: 15 + (i * 2),
                windDirection: "SW",
                symbolName: icons[i % icons.count],
                iconDescriptor: descs[i % descs.count],
                isNight: isN
            )
        }
    }
}

// MARK: - Widget Data Store

enum WidgetDataStore {
    private static let snapshotKey = "papaWeather.widgetWeatherSnapshot"
    private static let lastCoordinateKey = "papaWeather.widgetLastCoordinate"

    static func saveSnapshot(bundle: WeatherService.WeatherBundle) {
        let hourlyCurrent = bundle.hourlyForecast?.current
        let latest = bundle.weather.latest

        // Require either the hourly forecast's current hour or a station observation to proceed
        guard hourlyCurrent != nil || latest != nil else { return }

        let isNight: Bool
        if let hourlyCurrent {
            isNight = hourlyCurrent.isNight
        } else if let astroDay = bundle.astronomy?.days.first,
                  let sunrise = astroDay.sunriseDate,
                  let sunset = astroDay.sunsetDate {
            let now = Date()
            isNight = now < sunrise || now > sunset
        } else {
            isNight = false
        }

        // Primary source: hourly forecast's current condition (as shown in the Hourly tab)
        // Fallback: weather station latest observation
        let temp: Double = hourlyCurrent.map { Double($0.temp) }
            ?? latest?.airTemp
            ?? 0.0

        let apparentTemp: Double = hourlyCurrent.map { Double($0.feelsLike) }
            ?? latest?.apparentTemp
            ?? temp

        let humidity: Int = hourlyCurrent?.relativeHumidity
            ?? latest?.relHumidity
            ?? 0

        let windSpeedKmh: Int = hourlyCurrent?.windSpeedKmh
            ?? latest?.windSpeedKmh
            ?? 0

        let windDirection: String = hourlyCurrent?.windDirection
            ?? latest?.windDir
            ?? ""

        let rainChance: Int = hourlyCurrent?.rainChance
            ?? bundle.forecast?.days.first?.rainChancePercent
            ?? 0

        let descriptor: String = hourlyCurrent?.iconDescriptor
            ?? latest?.cloud.lowercased()
            ?? "clear"

        let conditionText: String = hourlyCurrent?.iconDescriptor
            .replacingOccurrences(of: "_", with: " ")
            .capitalized
            ?? (latest?.cloud.isEmpty == false ? latest!.cloud.capitalized : "Clear")

        let symbolName: String = hourlyCurrent?.symbolName
            ?? latest?.symbolName(isNight: isNight)
            ?? (isNight ? "moon.stars.fill" : "sun.max.fill")

        let hourlyItems: [WidgetHourlyItem] = bundle.hourlyForecast?.hours.prefix(12).map { h in
            WidgetHourlyItem(
                id: h.id.uuidString,
                date: h.rawDate,
                time: h.time,
                temp: h.temp,
                feelsLike: h.feelsLike,
                rainChance: h.rainChance,
                windSpeedKmh: h.windSpeedKmh,
                windDirection: h.windDirection,
                symbolName: h.symbolName,
                iconDescriptor: h.iconDescriptor,
                isNight: h.isNight
            )
        } ?? []

        let entry = WidgetWeatherEntry(
            date: .now,
            locality: bundle.locality ?? "Current Location",
            stationName: bundle.weather.stationName,
            temp: temp,
            apparentTemp: apparentTemp,
            conditionText: conditionText,
            symbolName: symbolName,
            iconDescriptor: descriptor,
            isNight: isNight,
            humidity: humidity,
            windSpeedKmh: windSpeedKmh,
            windDirection: windDirection,
            rainChance: rainChance,
            hourlyForecast: hourlyItems,
            isPlaceholder: false
        )

        save(entry: entry)
        WidgetCenter.shared.reloadAllTimelines()
    }

    static func save(entry: WidgetWeatherEntry) {
        guard let data = try? JSONEncoder().encode(entry) else { return }
        SharedAppStorage.defaults.set(data, forKey: snapshotKey)
    }

    static func load() -> WidgetWeatherEntry? {
        guard let data = SharedAppStorage.defaults.data(forKey: snapshotKey) else { return nil }
        return try? JSONDecoder().decode(WidgetWeatherEntry.self, from: data)
    }

    static func saveCoordinate(_ coordinate: CLLocationCoordinate2D) {
        let dict: [String: Double] = ["lat": coordinate.latitude, "lon": coordinate.longitude]
        SharedAppStorage.defaults.set(dict, forKey: lastCoordinateKey)
    }

    static func loadCoordinate() -> CLLocationCoordinate2D? {
        guard let dict = SharedAppStorage.defaults.dictionary(forKey: lastCoordinateKey),
              let lat = dict["lat"] as? Double,
              let lon = dict["lon"] as? Double else {
            return nil
        }
        return CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }
}
