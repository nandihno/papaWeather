//
//  LocationSelectionStore.swift
//  papaWeather
//

import Foundation
import Observation
import SwiftUI

/// Single source of truth for the user's saved locations and the currently active
/// selection. Every weather tab reads `selection` from here, so switching in one
/// place updates them all. Backed by `UserDefaults`, so both the list and the
/// active choice survive relaunch.
@Observable
final class LocationSelectionStore {

    static let shared = LocationSelectionStore()

    private(set) var saved: [SavedLocation] = []

    /// The active location. Defaults to `.currentDevice` — the app's original behaviour.
    var selection: ActiveLocation = .currentDevice {
        didSet { persistSelection() }
    }

    private let savedKey = "papaWeather.savedLocations"
    private let selectionKey = "papaWeather.activeLocationID"

    private init() {
        load()
    }

    // MARK: - Mutations

    func add(_ location: SavedLocation) {
        saved.append(location)
        persistSaved()
    }

    func delete(offsets: IndexSet) {
        let removed = offsets.map { saved[$0] }
        saved.remove(atOffsets: offsets)
        persistSaved()
        // If the active location was just deleted, fall back to the device location.
        if let active = selection.savedLocation, removed.contains(active) {
            selection = .currentDevice
        }
    }

    // MARK: - Persistence

    private func persistSaved() {
        guard let data = try? JSONEncoder().encode(saved) else { return }
        UserDefaults.standard.set(data, forKey: savedKey)
    }

    private func persistSelection() {
        switch selection {
        case .currentDevice:
            UserDefaults.standard.removeObject(forKey: selectionKey)
        case .saved(let location):
            UserDefaults.standard.set(location.id.uuidString, forKey: selectionKey)
        }
    }

    private func load() {
        if let data = UserDefaults.standard.data(forKey: savedKey),
           let locations = try? JSONDecoder().decode([SavedLocation].self, from: data) {
            saved = locations
        }

        // Restore the active selection only if it still exists in the saved list.
        if let idString = UserDefaults.standard.string(forKey: selectionKey),
           let id = UUID(uuidString: idString),
           let match = saved.first(where: { $0.id == id }) {
            selection = .saved(match)
        } else {
            selection = .currentDevice
        }
    }
}
