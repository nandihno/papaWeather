//
//  RainbowTileOverlay.swift
//  papaWeather
//

import CoreLocation
import MapKit
import Observation

// MARK: - Tile loading tracker

@Observable
@MainActor
final class RadarTileTracker {
    static let shared = RadarTileTracker()
    private(set) var activeRequests: Int = 0
    var isLoading: Bool { activeRequests > 0 }

    private init() {}

    nonisolated func begin() {
        Task { @MainActor in self.activeRequests += 1 }
    }

    nonisolated func end() {
        Task { @MainActor in self.activeRequests = max(0, self.activeRequests - 1) }
    }
}

// MARK: - Tile overlay

final class RainbowTileOverlay: MKTileOverlay {
    let snapshot: Int
    let forecastOffset: Int
    var userCoordinate: CLLocationCoordinate2D?

    private static let maxRadiusMeters: Double = 200_000

    init(snapshot: Int, forecastOffset: Int, userCoordinate: CLLocationCoordinate2D? = nil) {
        self.snapshot = snapshot
        self.forecastOffset = forecastOffset
        self.userCoordinate = userCoordinate
        super.init(urlTemplate: nil)
        canReplaceMapContent = false
        minimumZ = 1
        maximumZ = 12
    }

    override func url(forTilePath path: MKTileOverlayPath) -> URL {
        let urlString = "https://api.rainbow.ai/tiles/v1/precip/\(snapshot)/\(forecastOffset)/\(path.z)/\(path.x)/\(path.y)"
        guard var components = URLComponents(string: urlString) else {
            return URL(string: "https://api.rainbow.ai")!
        }
        components.queryItems = [
            URLQueryItem(name: "token", value: RainbowConfig.apiKey),
            URLQueryItem(name: "color", value: "0")
        ]
        return components.url ?? URL(string: "https://api.rainbow.ai")!
    }

    override func loadTile(at path: MKTileOverlayPath,
                           result: @escaping (Data?, Error?) -> Void) {
        if let coord = userCoordinate,
           !tileIntersectsRadius(path: path, userCoord: coord) {
            result(nil, nil)
            return
        }

        let tileURL = url(forTilePath: path)
        var request = URLRequest(url: tileURL,
                                 cachePolicy: .returnCacheDataElseLoad,
                                 timeoutInterval: 15)
        request.setValue("gzip, deflate", forHTTPHeaderField: "Accept-Encoding")

        RadarTileTracker.shared.begin()
        URLSession.shared.dataTask(with: request) { data, _, error in
            RadarTileTracker.shared.end()
            result(data, error)
        }.resume()
    }

    // Returns true if the tile's bounding box has any point within the allowed radius.
    // Uses the closest point on the tile to the user so tiles that straddle the boundary
    // are still fetched, while fully-outside tiles are skipped entirely.
    private func tileIntersectsRadius(path: MKTileOverlayPath,
                                      userCoord: CLLocationCoordinate2D) -> Bool {
        let n = pow(2.0, Double(path.z))
        let minLon = Double(path.x) / n * 360.0 - 180.0
        let maxLon = Double(path.x + 1) / n * 360.0 - 180.0
        let maxLat = atan(sinh(.pi * (1.0 - 2.0 * Double(path.y) / n))) * 180.0 / .pi
        let minLat = atan(sinh(.pi * (1.0 - 2.0 * Double(path.y + 1) / n))) * 180.0 / .pi

        let clampedLat = min(max(userCoord.latitude, minLat), maxLat)
        let clampedLon = min(max(userCoord.longitude, minLon), maxLon)

        let closest = CLLocation(latitude: clampedLat, longitude: clampedLon)
        let user    = CLLocation(latitude: userCoord.latitude, longitude: userCoord.longitude)
        return user.distance(from: closest) <= Self.maxRadiusMeters
    }
}
