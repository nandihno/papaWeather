//
//  OpenWeatherMapConfig.swift
//  papaWeather
//

import Foundation

enum OpenWeatherMapConfig {
    static let apiKey: String = {
        Bundle.main.infoDictionary?["OWM_API_KEY"] as? String ?? ""
    }()
}
