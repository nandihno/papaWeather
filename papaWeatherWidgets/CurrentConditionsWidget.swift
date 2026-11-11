//
//  CurrentConditionsWidget.swift
//  papaWeatherWidgets
//

import CoreLocation
import SwiftUI
import WidgetKit

struct CurrentConditionsProvider: TimelineProvider {
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
            // Default Melbourne Olympic Park
            coordinate = CLLocation(latitude: -37.8136, longitude: 144.9631)
        }

        do {
            let bundle = try await WeatherService.shared.fetchWeatherBundle(coordinate: coordinate)
            WidgetDataStore.saveSnapshot(bundle: bundle)
            if let fresh = WidgetDataStore.load() {
                return fresh
            }
        } catch {
            print("Widget conditions fetch failed: \(error.localizedDescription)")
        }

        return WidgetDataStore.load() ?? .placeholder()
    }
}

struct CurrentConditionsWidget: Widget {
    let kind: String = "CurrentConditionsWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: CurrentConditionsProvider()) { entry in
            CurrentConditionsWidgetView(entry: entry)
                .containerBackground(for: .widget) {
                    WidgetBackgroundView(
                        descriptor: entry.iconDescriptor,
                        isNight: entry.isNight,
                        temp: entry.temp
                    )
                }
        }
        .configurationDisplayName("Current Conditions")
        .description("Current temperature, weather condition, and local observations for your location.")
        .supportedFamilies([
            .systemSmall,
            .systemMedium,
            .accessoryCircular,
            .accessoryRectangular,
            .accessoryInline
        ])
    }
}
