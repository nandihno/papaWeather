//
//  WeatherService.swift
//  papaWeather
//

import Foundation
import CoreLocation
import MapKit

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
    private static let astronomicalURL = URL(string: "https://api.geodesyapps.ga.gov.au/astronomical/submitRequest")!

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
        let astronomy: AstronomicalInfo?
        let locality: String?
    }

    func fetchWeatherBundle() async throws -> WeatherBundle {
        let deviceLocation = try await locationManager.currentLocation()

        // Look up BOM location once — shared by both daily and hourly fetches
        let bomLocation = try? await fetchLocationLookup(
            lat: deviceLocation.coordinate.latitude,
            lon: deviceLocation.coordinate.longitude
        ).data.first

        async let weatherTask = fetchWeather(for: deviceLocation)
        async let forecastTask = fetchDailyForecast(bomLocation: bomLocation)
        async let hourlyTask = fetchHourlyForecast(bomLocation: bomLocation)
        async let astronomyTask = fetchAstronomy(for: deviceLocation)
        async let localityTask = fetchLocality(for: deviceLocation)
        let weather = try await weatherTask
        let forecast = try? await forecastTask
        let hourly = try? await hourlyTask
        let astronomy = try? await astronomyTask
        let locality = await localityTask
        return WeatherBundle(
            weather: weather,
            forecast: forecast,
            hourlyForecast: hourly,
            astronomy: astronomy,
            locality: locality
        )
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

    private func fetchDailyForecast(bomLocation: BOMLocationSearchItem?) async throws -> DailyForecastInfo {
        guard let bomLocation else { throw WeatherError.noForecastLocation }

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

        let isoParser = ISO8601DateFormatter()
        isoParser.formatOptions = [.withInternetDateTime]

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
                },
                sunriseDate: point.astronomical?.sunriseTime.flatMap { isoParser.date(from: $0) },
                sunsetDate:  point.astronomical?.sunsetTime.flatMap  { isoParser.date(from: $0) }
            )
        }

        return DailyForecastInfo(locationName: bomLocation.name,
                                 geohash: bomLocation.geohash,
                                 days: Array(days))
    }

    private func fetchHourlyForecast(bomLocation: BOMLocationSearchItem?) async throws -> HourlyForecastInfo {
        guard let bomLocation else { throw WeatherError.noForecastLocation }

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

        func makeHour(_ point: BOMHourlyForecastPoint, date: Date) -> HourlyForecastHour {
            HourlyForecastHour(
                rawDate: date,
                time: timeFmt.string(from: date),
                temp: point.temp ?? 0,
                feelsLike: point.tempFeelsLike ?? 0,
                rainChance: point.rain?.chance ?? 0,
                windSpeedKmh: point.wind?.speedKilometre ?? 0,
                windDirection: point.wind?.direction ?? "—",
                gustSpeedKmh: point.wind?.gustSpeedKilometre ?? 0,
                relativeHumidity: point.relativeHumidity ?? 0,
                iconDescriptor: point.iconDescriptor ?? "mostly_sunny",
                isNight: point.isNight ?? false
            )
        }

        let dated: [(BOMHourlyForecastPoint, Date)] = response.data.compactMap { point in
            guard let date = iso.date(from: point.time) else { return nil }
            return (point, date)
        }

        // Most recent entry whose time is at or before now
        let current: HourlyForecastHour? = dated
            .filter { $0.1 <= now }
            .max(by: { $0.1 < $1.1 })
            .map { makeHour($0.0, date: $0.1) }

        // All future hours (no cap)
        let hours: [HourlyForecastHour] = dated
            .filter { $0.1 > now }
            .map { makeHour($0.0, date: $0.1) }

        return HourlyForecastInfo(current: current, hours: hours)
    }

    private func fetchAstronomy(for deviceLocation: CLLocation) async throws -> AstronomicalInfo {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: Date())
        let dates = (0..<10).compactMap { calendar.date(byAdding: .day, value: $0, to: start) }
        var days: [AstronomicalDay] = []
        var latitude = ""
        var longitude = ""
        var timeZoneDescription = Self.timeZoneDescription(for: start)

        for date in dates {
            do {
                let response = try await fetchAstronomicalDay(for: deviceLocation, date: date)
                if !response.latitude.isEmpty { latitude = response.latitude }
                if !response.longitude.isEmpty { longitude = response.longitude }
                if !response.timeZoneDescription.isEmpty { timeZoneDescription = response.timeZoneDescription }
                days.append(response.day)
            } catch is CancellationError {
                throw CancellationError()
            } catch {
                continue
            }
        }

        guard !days.isEmpty else { throw WeatherError.noForecastLocation }

        return AstronomicalInfo(
            latitude: latitude,
            longitude: longitude,
            timeZoneDescription: timeZoneDescription,
            days: days
        )
    }

    private func fetchAstronomicalDay(for location: CLLocation, date: Date) async throws -> AstronomicalDayResponse {
        var request = URLRequest(url: Self.astronomicalURL)
        request.httpMethod = "POST"
        request.timeoutInterval = 15
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.httpBody = try JSONEncoder().encode(
            AstronomicalSubmitRequest(
                type: "sunrisenset",
                query: Self.astronomicalQuery(for: location.coordinate, date: date)
            )
        )

        let rawData: Data
        let response: URLResponse
        do {
            (rawData, response) = try await session.data(for: request)
        } catch {
            try rethrowIfCancelled(error)
            throw WeatherError.network(error)
        }

        guard let httpResponse = response as? HTTPURLResponse,
              (200..<300).contains(httpResponse.statusCode) else {
            throw WeatherError.noForecastLocation
        }

        let payload: AstronomicalSubmitResponse
        do {
            payload = try JSONDecoder().decode(AstronomicalSubmitResponse.self, from: rawData)
        } catch {
            throw WeatherError.decoding(error)
        }

        guard let event = payload.response.events.first else {
            throw WeatherError.noForecastLocation
        }

        let day = AstronomicalDay(
            id: Self.isoDay(from: date),
            date: date,
            sunriseDate: Self.astronomicalDate(
                event.rise,
                on: date,
                dayMarker: event.riseDay
            ),
            sunsetDate: Self.astronomicalDate(
                event.sunset,
                on: date,
                dayMarker: event.setDay
            )
        )

        return AstronomicalDayResponse(
            day: day,
            latitude: payload.response.latitude,
            longitude: payload.response.longitude,
            timeZoneDescription: event.timeZone
        )
    }

    // MARK: - Mapping

    private func mapToWeatherInfo(response: BOMResponse, fallbackTitle: String) -> WeatherInfo {
        let stationName = response.observations.header.first?.name ?? fallbackTitle

        let observations: [WeatherObservation] = response.observations.data
            .prefix(8)
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

    private func fetchLocality(for location: CLLocation) async -> String? {
        if #available(iOS 26.0, *) {
            guard let request = MKReverseGeocodingRequest(location: location) else { return nil }
            let mapItem = (try? await request.mapItems)?.first
            return mapItem?.addressRepresentations?.cityName
                ?? mapItem?.address?.shortAddress
                ?? mapItem?.name
        } else {
            let geocoder = CLGeocoder()
            let placemarks = try? await geocoder.reverseGeocodeLocation(location)
            let placemark = placemarks?.first
            return placemark?.locality ?? placemark?.subLocality ?? placemark?.name
        }
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

    private static func isoDay(from date: Date) -> String {
        let fmt = DateFormatter()
        fmt.locale = Locale(identifier: "en_US_POSIX")
        fmt.calendar = Calendar(identifier: .gregorian)
        fmt.dateFormat = "yyyy-MM-dd"
        return fmt.string(from: date)
    }

    private static func astronomicalQuery(for coordinate: CLLocationCoordinate2D, date: Date) -> String {
        let latitude = degreesAndMinutes(for: coordinate.latitude)
        let longitude = degreesAndMinutes(for: coordinate.longitude)
        return [
            "longdeg=\(longitude.degrees)",
            "longmin=\(longitude.minutes)",
            "latdeg=\(latitude.degrees)",
            "latmin=\(latitude.minutes)",
            "location=",
            "longhemi=\(coordinate.longitude < 0 ? "West" : "East")",
            "lathemi=\(coordinate.latitude < 0 ? "South" : "North")",
            "loc=yes",
            "timezone=\(timeZoneQueryValue(for: date))",
            "date=\(astronomicalDateString(from: date))",
            "Event=1"
        ].joined(separator: "&")
    }

    private static func degreesAndMinutes(for value: Double) -> (degrees: Int, minutes: Int) {
        var degrees = Int(value.rounded(.towardZero))
        var minutes = Int((abs(value - Double(degrees)) * 60).rounded())

        if minutes == 60 {
            minutes = 0
            degrees += value < 0 ? -1 : 1
        }

        return (degrees, minutes)
    }

    private static func astronomicalDateString(from date: Date) -> String {
        let fmt = DateFormatter()
        fmt.locale = Locale(identifier: "en_US_POSIX")
        fmt.calendar = Calendar(identifier: .gregorian)
        fmt.dateFormat = "dd/MM/yyyy"
        return fmt.string(from: date)
    }

    private static func timeZoneQueryValue(for date: Date) -> String {
        let hours = Double(TimeZone.current.secondsFromGMT(for: date)) / 3600.0
        var value = String(format: "%.2f", hours)
        while value.contains(".") && value.last == "0" {
            value.removeLast()
        }
        if value.last == "." { value.removeLast() }
        return value
    }

    private static func timeZoneDescription(for date: Date) -> String {
        let hours = Double(TimeZone.current.secondsFromGMT(for: date)) / 3600.0
        return String(format: "%+.2f hours", hours)
    }

    private static func astronomicalDate(
        _ time: String?,
        on date: Date,
        dayMarker: String?
    ) -> Date? {
        guard let time = time?.trimmingCharacters(in: .whitespacesAndNewlines),
              time.count == 4,
              let hour = Int(time.prefix(2)),
              let minute = Int(time.suffix(2)) else {
            return nil
        }

        var calendar = Calendar.current
        calendar.timeZone = .current
        var components = calendar.dateComponents([.year, .month, .day], from: date)
        components.hour = hour
        components.minute = minute
        guard var result = calendar.date(from: components) else { return nil }

        let marker = dayMarker?.uppercased() ?? "SAME"
        if marker.contains("NEXT") {
            result = calendar.date(byAdding: .day, value: 1, to: result) ?? result
        } else if marker.contains("PREV") {
            result = calendar.date(byAdding: .day, value: -1, to: result) ?? result
        }

        return result
    }
}

private struct AstronomicalSubmitRequest: Encodable {
    let type: String
    let query: String
}

private struct AstronomicalSubmitResponse: Decodable {
    let response: AstronomicalResponse
}

private struct AstronomicalResponse: Decodable {
    let latitude: String
    let longitude: String
    let events: [AstronomicalEvent]
}

private struct AstronomicalEvent: Decodable {
    let timeZone: String
    let rise: String?
    let riseDay: String?
    let sunset: String?
    let setDay: String?

    enum CodingKeys: String, CodingKey {
        case timeZone = "time_zone"
        case rise
        case riseDay = "rise_day"
        case sunset = "set"
        case setDay = "set_day"
    }
}

private struct AstronomicalDayResponse {
    let day: AstronomicalDay
    let latitude: String
    let longitude: String
    let timeZoneDescription: String
}
