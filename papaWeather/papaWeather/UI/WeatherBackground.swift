//
//  WeatherBackground.swift
//  papaWeather
//

import SwiftUI

enum WeatherBackground {
    static func gradient(
        for hour: HourlyForecastHour?,
        colorScheme: ColorScheme
    ) -> LinearGradient? {
        guard let hour else { return nil }
        let colors = colors(for: hour, colorScheme: colorScheme)
        return LinearGradient(
            colors: colors,
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private static func colors(
        for hour: HourlyForecastHour,
        colorScheme: ColorScheme
    ) -> [Color] {
        let desc = hour.iconDescriptor.lowercased()
        let temp = hour.temp
        let isDark = colorScheme == .dark

        if hour.isNight {
            return isDark
                ? [Color(red: 0.01, green: 0.02, blue: 0.10), Color(red: 0.03, green: 0.06, blue: 0.22)]
                : [Color(red: 0.05, green: 0.10, blue: 0.30), Color(red: 0.11, green: 0.18, blue: 0.45)]
        }

        if temp >= 32 {
            return isDark
                ? [Color(red: 0.55, green: 0.08, blue: 0.06), Color(red: 0.92, green: 0.27, blue: 0.10)]
                : [Color(red: 1.00, green: 0.32, blue: 0.20), Color(red: 0.85, green: 0.10, blue: 0.10)]
        }

        if temp <= 5 {
            return isDark
                ? [Color(red: 0.02, green: 0.18, blue: 0.42), Color(red: 0.10, green: 0.42, blue: 0.78)]
                : [Color(red: 0.40, green: 0.74, blue: 1.00), Color(red: 0.10, green: 0.40, blue: 0.85)]
        }

        if desc.contains("storm") || desc.contains("thunder") || desc.contains("rain") || desc.contains("shower") {
            return isDark
                ? [Color(red: 0.08, green: 0.12, blue: 0.20), Color(red: 0.18, green: 0.24, blue: 0.34)]
                : [Color(red: 0.35, green: 0.45, blue: 0.58), Color(red: 0.18, green: 0.28, blue: 0.42)]
        }

        if desc.contains("partly") || desc.contains("mostly_sunny") {
            return isDark
                ? [Color(red: 0.14, green: 0.32, blue: 0.58), Color(red: 0.32, green: 0.36, blue: 0.42)]
                : [Color(red: 0.30, green: 0.62, blue: 0.95), Color(red: 0.62, green: 0.66, blue: 0.72)]
        }

        if desc.contains("cloudy") || desc.contains("overcast") {
            return isDark
                ? [Color(red: 0.18, green: 0.20, blue: 0.24), Color(red: 0.34, green: 0.38, blue: 0.42)]
                : [Color(red: 0.62, green: 0.64, blue: 0.68), Color(red: 0.40, green: 0.44, blue: 0.48)]
        }

        if desc.contains("hazy") || desc.contains("fog") || desc.contains("mist") || desc.contains("dust") || desc.contains("smoke") {
            return isDark
                ? [Color(red: 0.26, green: 0.28, blue: 0.32), Color(red: 0.42, green: 0.46, blue: 0.50)]
                : [Color(red: 0.68, green: 0.72, blue: 0.76), Color(red: 0.50, green: 0.56, blue: 0.62)]
        }

        // sunny / clear / fine
        return isDark
            ? [Color(red: 0.02, green: 0.22, blue: 0.50), Color(red: 0.08, green: 0.42, blue: 0.78)]
            : [Color(red: 0.20, green: 0.62, blue: 0.98), Color(red: 0.06, green: 0.42, blue: 0.88)]
    }
}
