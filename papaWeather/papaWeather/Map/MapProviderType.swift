//
//  MapProviderType.swift
//  papaWeather
//

import MapKit

enum MapProviderType: String, CaseIterable {
    case rainbow = "rainbow"
    case openWeatherMap = "openWeatherMap"

    var displayName: String {
        switch self {
        case .rainbow: return "Radar"
        case .openWeatherMap: return "Weather"
        }
    }

    var supportsAnimation: Bool { false }

    var frames: [Int] { [0] }

    var loadingLabel: String {
        switch self {
        case .rainbow: return "Loading radar…"
        case .openWeatherMap: return "Loading map…"
        }
    }

    var fetchingLabel: String {
        switch self {
        case .rainbow: return "Fetching radar…"
        case .openWeatherMap: return "Fetching tiles…"
        }
    }

    func makeTileOverlay(snapshot: Int, forecastOffset: Int, owmLayer: OWMLayer = .precipitation) -> MKTileOverlay {
        switch self {
        case .rainbow:
            return RainbowTileOverlay(snapshot: snapshot, forecastOffset: forecastOffset)
        case .openWeatherMap:
            return OpenWeatherMapTileOverlay(layer: owmLayer)
        }
    }

    func fetchSnapshot() async throws -> Int {
        switch self {
        case .rainbow:
            let snapshot = try await RadarSnapshotService.shared.fetchLatestSnapshot()
            await RadarSnapshotService.shared.startAutoRefresh()
            return snapshot
        case .openWeatherMap:
            await RadarSnapshotService.shared.stopAutoRefresh()
            return 0
        }
    }
}
