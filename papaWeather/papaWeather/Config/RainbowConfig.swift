//
//  RainbowConfig.swift
//  papaWeather
//
//  Reads RAINBOW_API_KEY from the app's Info.plist, which is populated at build
//  time from RainbowConfig.xcconfig.
//
//  Required Xcode one-time setup (see RainbowConfig.xcconfig for full steps):
//  - Assign RainbowConfig.xcconfig to your build configurations
//  - Add RAINBOW_API_KEY = $(RAINBOW_API_KEY) as a custom Info.plist entry
//

import Foundation

enum RainbowConfig {
    static let apiKey: String = {
        Bundle.main.infoDictionary?["RAINBOW_API_KEY"] as? String ?? ""
    }()
}
