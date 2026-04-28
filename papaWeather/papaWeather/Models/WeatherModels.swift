//
//  WeatherModels.swift
//  papaWeather
//

import Foundation

// MARK: - Weather

struct WeatherObservation: Identifiable {
    let id = UUID()
    let localDateTime: String
    let apparentTemp: Double
    let airTemp: Double
    let pressureMSL: Double
    let relHumidity: Int
    let cloud: String
    let windDir: String
    let windSpeedKmh: Int

    var symbolName: String {
        let c = cloud.lowercased()
        if c == "sunny" || c == "clear" || c.hasPrefix("fine") { return "sun.max.fill" }
        if c.contains("shower") || c.contains("rain")          { return "cloud.rain.fill" }
        if c.contains("storm") || c.contains("thunder")        { return "cloud.bolt.rain.fill" }
        if c.contains("partly")                                 { return "cloud.sun.fill" }
        if c.contains("fog") || c.contains("mist")             { return "cloud.fog.fill" }
        return "cloud.fill"
    }
}

struct WeatherInfo: Identifiable {
    let id = UUID()
    let stationName: String
    let observations: [WeatherObservation]

    var latest: WeatherObservation? { observations.first }
}

// MARK: - Hourly Forecast

struct HourlyForecastHour: Identifiable {
    let id = UUID()
    let time: String
    let temp: Int
    let feelsLike: Int
    let rainChance: Int
    let iconDescriptor: String
    let isNight: Bool
}

struct HourlyForecastInfo {
    let hours: [HourlyForecastHour]
}

// MARK: - Daily Forecast

struct DailyForecastNow {
    let isNight: Bool?
    let nowLabel: String?
    let laterLabel: String?
    let tempNow: Int?
    let tempLater: Int?
}

struct DailyForecastDay: Identifiable {
    let id: String
    let date: String
    let chanceOfNoRainCategory: String?
    let rainChancePercent: Int?
    let rainAmountMinMm: Int?
    let rainAmountMaxMm: Int?
    let tempMax: Int?
    let tempMin: Int?
    let extendedText: String?
    let shortText: String?
    let fireDanger: String?
    let uvCategory: String?
    let now: DailyForecastNow?
}

struct DailyForecastInfo {
    let locationName: String
    let geohash: String
    let days: [DailyForecastDay]

    func debugSummary(limit: Int = 7) -> String {
        days.prefix(limit).map { day in
            var parts: [String] = []
            parts.append("\(day.date): \(temperatureString(for: day))")
            parts.append((day.shortText?.trimmingCharacters(in: .whitespacesAndNewlines)).flatMap {
                $0.isEmpty ? nil : $0
            } ?? "No summary")
            parts.append("Rain: \(rainString(for: day))")
            if let noRain = day.chanceOfNoRainCategory?.trimmingCharacters(in: .whitespacesAndNewlines),
               !noRain.isEmpty {
                parts.append("No-rain: \(noRain)")
            }
            if let fire = day.fireDanger?.trimmingCharacters(in: .whitespacesAndNewlines), !fire.isEmpty {
                parts.append("Fire: \(fire)")
            }
            if let uv = day.uvCategory?.trimmingCharacters(in: .whitespacesAndNewlines), !uv.isEmpty {
                parts.append("UV: \(uv)")
            }
            if let nowText = nowString(for: day.now), !nowText.isEmpty {
                parts.append(nowText)
            }

            var line = parts.joined(separator: " | ")
            if let extended = day.extendedText?.trimmingCharacters(in: .whitespacesAndNewlines), !extended.isEmpty {
                line += "\n  -> \(extended)"
            }
            return line
        }
        .joined(separator: "\n\n")
    }

    private func temperatureString(for day: DailyForecastDay) -> String {
        switch (day.tempMin, day.tempMax) {
        case let (min?, max?): return "\(min)-\(max)°C"
        case let (nil, max?): return "max \(max)°C"
        case let (min?, nil): return "min \(min)°C"
        case (nil, nil): return "n/a"
        }
    }

    private func rainString(for day: DailyForecastDay) -> String {
        let chance = day.rainChancePercent.map { "\($0)%" } ?? "n/a"
        guard let min = day.rainAmountMinMm else { return chance }
        guard let max = day.rainAmountMaxMm else {
            return min > 0 ? "\(chance) (\(min)mm)" : chance
        }
        if max > 0 { return "\(chance) (\(min)-\(max)mm)" }
        return chance
    }

    private func nowString(for now: DailyForecastNow?) -> String? {
        guard let now else { return nil }
        var pieces: [String] = []
        if let nowLabel = now.nowLabel, let tempNow = now.tempNow {
            pieces.append("\(nowLabel): \(tempNow)°C")
        }
        if let laterLabel = now.laterLabel, let tempLater = now.tempLater {
            pieces.append("\(laterLabel): \(tempLater)°C")
        }
        guard !pieces.isEmpty else { return nil }
        return pieces.joined(separator: ", ")
    }
}
