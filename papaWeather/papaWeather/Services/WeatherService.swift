//
//  WeatherService.swift
//  papaWeather
//

import Foundation
import CoreLocation

// MARK: - Errors

enum WeatherError: LocalizedError {
    case noStations
    case noForecastLocation
    case network(Error)
    case decoding(Error)

    var errorDescription: String? {
        switch self {
        case .noStations:         return "No weather stations available."
        case .noForecastLocation: return "No BOM forecast location found for current coordinates."
        case .network(let e):     return "Network error: \(e.localizedDescription)"
        case .decoding(let e):    return "Data error: \(e.localizedDescription)"
        }
    }
}

// MARK: - Weather Service

final class WeatherService {
    static let shared = WeatherService()
    private static let weatherBaseURL = "https://api.weather.bom.gov.au/v1"

    private let locationManager = LocationManager()
    private let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 15
        return URLSession(configuration: config)
    }()

    private init() {}

    private func rethrowIfCancelled(_ error: Error) throws {
        if error is CancellationError { throw CancellationError() }
        let nsError = error as NSError
        if nsError.domain == NSURLErrorDomain, nsError.code == URLError.cancelled.rawValue {
            throw CancellationError()
        }
    }

    struct WeatherBundle {
        let weather: WeatherInfo
        let forecast: DailyForecastInfo?
        let hourlyForecast: HourlyForecastInfo?
    }

    func fetchWeatherBundle() async throws -> WeatherBundle {
        let deviceLocation = try await locationManager.currentLocation()
        async let weatherTask = fetchWeather(for: deviceLocation)
        async let forecastTask = fetchDailyForecast(for: deviceLocation)
        async let hourlyTask = fetchHourlyForecast(for: deviceLocation)
        let weather = try await weatherTask
        let forecast = try? await forecastTask
        let hourly = try? await hourlyTask
        return WeatherBundle(weather: weather, forecast: forecast, hourlyForecast: hourly)
    }

    func fetchWeather() async throws -> WeatherInfo {
        let deviceLocation = try await locationManager.currentLocation()
        return try await fetchWeather(for: deviceLocation)
    }

    // MARK: - Private pipeline

    private func fetchWeather(for deviceLocation: CLLocation) async throws -> WeatherInfo {
        let allStations = WeatherStationStore.shared.all
        guard let station = WeatherStation.nearest(to: deviceLocation, from: allStations) else {
            throw WeatherError.noStations
        }

        guard let url = URL(string: station.url) else { throw WeatherError.noStations }
        let rawData: Data
        do {
            let (data, _) = try await session.data(from: url)
            rawData = data
        } catch {
            try rethrowIfCancelled(error)
            throw WeatherError.network(error)
        }

        let response: BOMResponse
        do {
            response = try JSONDecoder().decode(BOMResponse.self, from: rawData)
        } catch {
            throw WeatherError.decoding(error)
        }

        return mapToWeatherInfo(response: response, fallbackTitle: station.title)
    }

    private func fetchDailyForecast(for deviceLocation: CLLocation) async throws -> DailyForecastInfo {
        let locationLookup = try await fetchLocationLookup(lat: deviceLocation.coordinate.latitude,
                                                           lon: deviceLocation.coordinate.longitude)
        guard let bomLocation = locationLookup.data.first else {
            throw WeatherError.noForecastLocation
        }

        let geohash = String(bomLocation.geohash.prefix(6))
        guard let forecastURL = URL(string: "\(Self.weatherBaseURL)/locations/\(geohash)/forecasts/daily") else {
            throw WeatherError.noForecastLocation
        }

        let rawData: Data
        do {
            let (data, _) = try await session.data(from: forecastURL)
            rawData = data
        } catch {
            try rethrowIfCancelled(error)
            throw WeatherError.network(error)
        }

        let response: BOMDailyForecastResponse
        do {
            response = try JSONDecoder().decode(BOMDailyForecastResponse.self, from: rawData)
        } catch {
            throw WeatherError.decoding(error)
        }

        let days = response.data.prefix(7).map { point in
            DailyForecastDay(
                id: Self.isoDay(from: point.date),
                date: Self.isoDay(from: point.date),
                chanceOfNoRainCategory: point.rain?.chanceOfNoRainCategory,
                rainChancePercent: point.rain?.chance,
                rainAmountMinMm: point.rain?.amount?.min,
                rainAmountMaxMm: point.rain?.amount?.max,
                tempMax: point.tempMax,
                tempMin: point.tempMin,
                extendedText: point.extendedText,
                shortText: point.shortText,
                fireDanger: point.fireDanger,
                uvCategory: point.uv?.category,
                now: point.now.map {
                    DailyForecastNow(
                        isNight: $0.isNight,
                        nowLabel: $0.nowLabel,
                        laterLabel: $0.laterLabel,
                        tempNow: $0.tempNow,
                        tempLater: $0.tempLater
                    )
                }
            )
        }

        return DailyForecastInfo(locationName: bomLocation.name,
                                 geohash: bomLocation.geohash,
                                 days: Array(days))
    }

    private func fetchHourlyForecast(for deviceLocation: CLLocation) async throws -> HourlyForecastInfo {
        let locationLookup = try await fetchLocationLookup(lat: deviceLocation.coordinate.latitude,
                                                           lon: deviceLocation.coordinate.longitude)
        guard let bomLocation = locationLookup.data.first else {
            throw WeatherError.noForecastLocation
        }

        let geohash = String(bomLocation.geohash.prefix(6))
        guard let url = URL(string: "\(Self.weatherBaseURL)/locations/\(geohash)/forecasts/hourly") else {
            throw WeatherError.noForecastLocation
        }

        let rawData: Data
        do {
            let (data, _) = try await session.data(from: url)
            rawData = data
        } catch {
            try rethrowIfCancelled(error)
            throw WeatherError.network(error)
        }

        let response: BOMHourlyForecastResponse
        do {
            response = try JSONDecoder().decode(BOMHourlyForecastResponse.self, from: rawData)
        } catch {
            throw WeatherError.decoding(error)
        }

        let now = Date()
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime]

        let timeFmt = DateFormatter()
        timeFmt.dateFormat = "h a"

        let hours: [HourlyForecastHour] = response.data.compactMap { point in
            guard let date = iso.date(from: point.time) else { return nil }
            guard date >= now, date <= now.addingTimeInterval(5 * 3600) else { return nil }
            return HourlyForecastHour(
                time: timeFmt.string(from: date),
                temp: point.temp ?? 0,
                feelsLike: point.tempFeelsLike ?? 0,
                rainChance: point.rain?.chance ?? 0,
                iconDescriptor: point.iconDescriptor ?? "mostly_sunny",
                isNight: point.isNight ?? false
            )
        }

        return HourlyForecastInfo(hours: hours)
    }

    // MARK: - Mapping

    private func mapToWeatherInfo(response: BOMResponse, fallbackTitle: String) -> WeatherInfo {
        let stationName = response.observations.header.first?.name ?? fallbackTitle

        let observations: [WeatherObservation] = response.observations.data
            .prefix(10)
            .map { point in
                let raw = (point.cloud ?? "").trimmingCharacters(in: .whitespaces)
                let cloud = (raw.isEmpty || raw == "-") ? "Sunny" : raw

                let windDir = (point.windDir?.trimmingCharacters(in: .whitespaces) ?? "")
                    .replacingOccurrences(of: "-", with: "—")

                return WeatherObservation(
                    localDateTime: Self.timeOnly(from: point.localDateTime),
                    apparentTemp:  point.apparentT ?? point.airTemp ?? 0,
                    airTemp:       point.airTemp ?? 0,
                    pressureMSL:   point.pressMsl ?? 1013.25,
                    relHumidity:   point.relHum ?? 0,
                    cloud:         cloud,
                    windDir:       windDir.isEmpty ? "—" : windDir,
                    windSpeedKmh:  point.windSpdKmh ?? 0
                )
            }

        return WeatherInfo(stationName: stationName, observations: observations)
    }

    private static func timeOnly(from raw: String) -> String {
        let parts = raw.split(separator: "/", maxSplits: 1)
        return parts.count == 2 ? String(parts[1]) : raw
    }

    private func fetchLocationLookup(lat: Double, lon: Double) async throws -> BOMLocationSearchResponse {
        var components = URLComponents(string: "\(Self.weatherBaseURL)/locations")
        components?.queryItems = [URLQueryItem(name: "search", value: "\(lat),\(lon)")]

        guard let url = components?.url else {
            throw WeatherError.noForecastLocation
        }

        let rawData: Data
        do {
            let (data, _) = try await session.data(from: url)
            rawData = data
        } catch {
            try rethrowIfCancelled(error)
            throw WeatherError.network(error)
        }

        do {
            return try JSONDecoder().decode(BOMLocationSearchResponse.self, from: rawData)
        } catch {
            throw WeatherError.decoding(error)
        }
    }

    private static func isoDay(from value: String) -> String {
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime]
        if let date = iso.date(from: value) {
            let fmt = DateFormatter()
            fmt.locale = Locale(identifier: "en_US_POSIX")
            fmt.dateFormat = "yyyy-MM-dd"
            return fmt.string(from: date)
        }
        return String(value.prefix(10))
    }
}
