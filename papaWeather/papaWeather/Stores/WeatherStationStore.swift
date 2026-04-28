//
//  WeatherStationStore.swift
//  papaWeather
//

import Foundation
import Observation
import SwiftUI

@Observable
final class WeatherStationStore {

    static let shared = WeatherStationStore()

    private(set) var custom: [WeatherStation] = []

    var all: [WeatherStation] { WeatherStation.defaults + custom }

    private let storageKey = "papaWeather.customWeatherStations"

    private init() { load() }

    func add(_ station: WeatherStation) {
        custom.append(station)
        persist()
    }

    func delete(offsets: IndexSet) {
        custom.remove(atOffsets: offsets)
        persist()
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(custom) else { return }
        UserDefaults.standard.set(data, forKey: storageKey)
    }

    private func load() {
        guard
            let data     = UserDefaults.standard.data(forKey: storageKey),
            let stations = try? JSONDecoder().decode([WeatherStation].self, from: data)
        else { return }
        custom = stations
    }
}
