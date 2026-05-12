//
//  RadarMapViewModel.swift
//  papaWeather
//

import Foundation
import CoreLocation
import Observation

@Observable
@MainActor
final class RadarMapViewModel {
    var selectedProvider: MapProviderType
    var selectedOWMLayer: OWMLayer
    var currentSnapshot: Int = 0
    var frames: [Int]
    var selectedFrameIndex: Int = 0
    var isAnimating: Bool = false
    var isLoading: Bool = true
    var errorMessage: String? = nil
    var userCoordinate: CLLocationCoordinate2D? = nil

    private let locationManager = LocationManager()
    private var animationTask: Task<Void, Never>?

    init() {
        let stored = UserDefaults.standard.string(forKey: "mapProvider") ?? ""
        let provider = MapProviderType(rawValue: stored) ?? .rainbow
        selectedProvider = provider
        frames = provider.frames

        let storedLayer = UserDefaults.standard.string(forKey: "owmLayer") ?? ""
        selectedOWMLayer = OWMLayer(rawValue: storedLayer) ?? .precipitation
    }

    var formattedFrameTime: String {
        let offset = frames[selectedFrameIndex]
        if offset == 0 { return "Now" }
        let minutes = offset / 60
        if minutes < 60 { return "+\(minutes) min" }
        let hours = minutes / 60
        let remainder = minutes % 60
        return remainder == 0 ? "+\(hours) hr" : "+\(hours)h \(remainder)m"
    }

    func switchOWMLayer(to layer: OWMLayer) {
        guard layer != selectedOWMLayer else { return }
        selectedOWMLayer = layer
        UserDefaults.standard.set(layer.rawValue, forKey: "owmLayer")
    }

    func switchProvider(to provider: MapProviderType) {
        guard provider != selectedProvider else { return }
        stopAnimation()
        selectedProvider = provider
        frames = provider.frames
        selectedFrameIndex = 0
        UserDefaults.standard.set(provider.rawValue, forKey: "mapProvider")
        Task { await loadSnapshot() }
    }

    func loadSnapshot() async {
        isLoading = true
        errorMessage = nil

        if userCoordinate == nil {
            Task {
                if let location = try? await locationManager.currentLocation() {
                    userCoordinate = location.coordinate
                }
            }
        }

        do {
            currentSnapshot = try await selectedProvider.fetchSnapshot()
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func startAnimation() {
        guard !isAnimating else { return }
        isAnimating = true
        animationTask = Task {
            while !Task.isCancelled && isAnimating {
                try? await Task.sleep(for: .milliseconds(500))
                guard !Task.isCancelled && isAnimating else { return }
                selectedFrameIndex = (selectedFrameIndex + 1) % frames.count
            }
        }
    }

    func stopAnimation() {
        isAnimating = false
        animationTask?.cancel()
        animationTask = nil
    }

    func toggleAnimation() {
        isAnimating ? stopAnimation() : startAnimation()
    }
}
