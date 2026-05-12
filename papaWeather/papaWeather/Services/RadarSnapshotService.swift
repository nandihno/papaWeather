//
//  RadarSnapshotService.swift
//  papaWeather
//

import Foundation

actor RadarSnapshotService {
    static let shared = RadarSnapshotService()

    private static let baseURL = "https://api.rainbow.ai"
    private static let refreshInterval: Duration = .seconds(600)

    private(set) var latestSnapshot: Int = 0
    private var refreshTask: Task<Void, Never>?

    private let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 15
        return URLSession(configuration: config)
    }()

    private init() {}

    func fetchLatestSnapshot() async throws -> Int {
        guard var components = URLComponents(string: "\(Self.baseURL)/tiles/v1/snapshot") else {
            throw RadarError.invalidURL
        }
        components.queryItems = [URLQueryItem(name: "token", value: RainbowConfig.apiKey)]
        guard let url = components.url else { throw RadarError.invalidURL }

        let (data, response) = try await session.data(from: url)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw RadarError.badResponse
        }
        let decoded = try JSONDecoder().decode(SnapshotResponse.self, from: data)
        latestSnapshot = decoded.snapshot
        return decoded.snapshot
    }

    func buildTileURL(snapshot: Int, forecastOffset: Int, zoom: Int, x: Int, y: Int) -> URL? {
        guard var components = URLComponents(
            string: "\(Self.baseURL)/tiles/v1/precip/\(snapshot)/\(forecastOffset)/\(zoom)/\(x)/\(y)"
        ) else { return nil }
        components.queryItems = [
            URLQueryItem(name: "token", value: RainbowConfig.apiKey),
            URLQueryItem(name: "color", value: "5")
        ]
        return components.url
    }

    func startAutoRefresh() {
        refreshTask?.cancel()
        refreshTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(for: Self.refreshInterval)
                guard !Task.isCancelled else { return }
                _ = try? await fetchLatestSnapshot()
            }
        }
    }

    func stopAutoRefresh() {
        refreshTask?.cancel()
        refreshTask = nil
    }

    // MARK: - Types

    private struct SnapshotResponse: Decodable {
        let snapshot: Int
    }
}

enum RadarError: LocalizedError {
    case invalidURL
    case badResponse
    case noSnapshot

    var errorDescription: String? {
        switch self {
        case .invalidURL:    return "Invalid radar API URL."
        case .badResponse:   return "Unexpected response from radar service."
        case .noSnapshot:    return "No radar snapshot available."
        }
    }
}
