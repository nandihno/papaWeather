//
//  HourlyOverviewWidget.swift
//  papaWeatherWidgets
//

import CoreLocation
import SwiftUI
import WidgetKit

struct HourlyOverviewProvider: TimelineProvider {
    func placeholder(in context: Context) -> WidgetWeatherEntry {
        .placeholder()
    }

    func getSnapshot(in context: Context, completion: @escaping (WidgetWeatherEntry) -> Void) {
        if context.isPreview {
            completion(.placeholder())
            return
        }
        if let cached = WidgetDataStore.load() {
            completion(cached)
            return
        }
        completion(.placeholder())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<WidgetWeatherEntry>) -> Void) {
        Task {
            let entry = await fetchLiveEntry()
            let nextRefresh = Calendar.current.date(byAdding: .minute, value: 30, to: Date())
                ?? Date().addingTimeInterval(1800)
            let timeline = Timeline(entries: [entry], policy: .after(nextRefresh))
            completion(timeline)
        }
    }

    private func fetchLiveEntry() async -> WidgetWeatherEntry {
        let locationManager = await WidgetLocationManager()
        let location = await locationManager.currentLocation()

        let coordinate: CLLocation
        if let location {
            coordinate = location
            WidgetDataStore.saveCoordinate(location.coordinate)
        } else if let savedCoord = WidgetDataStore.loadCoordinate() {
            coordinate = CLLocation(latitude: savedCoord.latitude, longitude: savedCoord.longitude)
        } else {
            coordinate = CLLocation(latitude: -37.8136, longitude: 144.9631)
        }

        do {
            let bundle = try await WeatherService.shared.fetchWeatherBundle(coordinate: coordinate)
            WidgetDataStore.saveSnapshot(bundle: bundle)
            if let fresh = WidgetDataStore.load() {
                return fresh
            }
        } catch {
            print("Widget hourly fetch failed: \(error.localizedDescription)")
        }

        return WidgetDataStore.load() ?? .placeholder()
    }
}

struct HourlyOverviewWidget: Widget {
    let kind: String = "HourlyOverviewWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: HourlyOverviewProvider()) { entry in
            HourlyOverviewWidgetView(entry: entry)
                .containerBackground(for: .widget) {
                    WidgetBackgroundView(
                        descriptor: entry.iconDescriptor,
                        isNight: entry.isNight,
                        temp: entry.temp
                    )
                }
        }
        .configurationDisplayName("Hourly Overview")
        .description("Hourly weather progression, temperatures, and rain chances for your current location.")
        .supportedFamilies([
            .systemMedium,
            .systemLarge,
            .systemSmall
        ])
    }
}
