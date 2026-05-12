//
//  OpenWeatherMapTileOverlay.swift
//  papaWeather
//
//  OpenWeatherMap Weather Maps 1.0
//  Tile URL: https://tile.openweathermap.org/map/{layer}/{z}/{x}/{y}.png?appid={key}
//

import MapKit

enum OWMLayer: String, CaseIterable {
    case precipitation = "precipitation_new"
    case clouds = "clouds_new"
    case temperature = "temp_new"
    case wind = "wind_new"
    case pressure = "pressure_new"

    var displayName: String {
        switch self {
        case .precipitation: return "Rain"
        case .clouds:        return "Clouds"
        case .temperature:   return "Temp"
        case .wind:          return "Wind"
        case .pressure:      return "Pressure"
        }
    }
}

final class OpenWeatherMapTileOverlay: MKTileOverlay {
    let layer: OWMLayer

    init(layer: OWMLayer = .precipitation) {
        self.layer = layer
        super.init(urlTemplate: nil)
        canReplaceMapContent = false
        minimumZ = 1
        maximumZ = 12
    }

    override func url(forTilePath path: MKTileOverlayPath) -> URL {
        let urlString = "https://tile.openweathermap.org/map/\(layer.rawValue)/\(path.z)/\(path.x)/\(path.y).png"
        guard var components = URLComponents(string: urlString) else {
            return URL(string: "https://tile.openweathermap.org")!
        }
        components.queryItems = [URLQueryItem(name: "appid", value: OpenWeatherMapConfig.apiKey)]
        return components.url ?? URL(string: "https://tile.openweathermap.org")!
    }

    override func loadTile(at path: MKTileOverlayPath,
                           result: @escaping (Data?, Error?) -> Void) {
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
}
