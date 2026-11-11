//
//  WidgetViews.swift
//  papaWeatherWidgets
//

import SwiftUI
import WidgetKit

// MARK: - RGB Color & Luminance Helper

struct WidgetRGBColor {
    let r: Double
    let g: Double
    let b: Double

    var color: Color {
        Color(red: r, green: g, blue: b)
    }

    func mix(with other: WidgetRGBColor, by amount: Double) -> WidgetRGBColor {
        let clamped = max(0.0, min(1.0, amount))
        return WidgetRGBColor(
            r: r + (other.r - r) * clamped,
            g: g + (other.g - g) * clamped,
            b: b + (other.b - b) * clamped
        )
    }

    /// Perceived luminance (ITU-R BT.709)
    var luminance: Double {
        0.2126 * r + 0.7152 * g + 0.0722 * b
    }
}

// MARK: - Dynamic Widget Theme

struct WidgetTheme {
    let isLight: Bool
    let backgroundGradient: LinearGradient
    let ambientHighlightColor: Color

    // Dynamic Typography Colors
    let textPrimary: Color
    let textSecondary: Color
    let textTertiary: Color

    // Dynamic Card & Container Styling
    let cardBackground: Color
    let cardBorder: Color
    let chipBackground: Color
    let chipBorder: Color
    let dividerColor: Color

    // Dynamic Highlights & Accents
    let locationTint: Color
    let rainChipBackground: Color
    let rainChipText: Color
    let humidityTint: Color
    let windTint: Color
    let rainIconTint: Color
    let directionTint: Color

    init(descriptor: String, isNight: Bool, temp: Double, colorScheme: ColorScheme) {
        let isDark = colorScheme == .dark

        // Determine base and condition colors
        let baseTop: WidgetRGBColor
        let baseBottom: WidgetRGBColor
        let condColors: (WidgetRGBColor, WidgetRGBColor)
        let tintAmount: Double

        if isNight {
            // Nighttime uses atmospheric midnight blues
            condColors = (
                WidgetRGBColor(r: 0.03, g: 0.06, b: 0.18),
                WidgetRGBColor(r: 0.06, g: 0.10, b: 0.28)
            )
            baseTop = isDark
                ? WidgetRGBColor(r: 0.05, g: 0.10, b: 0.22)
                : WidgetRGBColor(r: 0.08, g: 0.14, b: 0.32)
            baseBottom = isDark
                ? WidgetRGBColor(r: 0.02, g: 0.04, b: 0.14)
                : WidgetRGBColor(r: 0.04, g: 0.08, b: 0.22)
            tintAmount = 0.50
        } else {
            // Daytime base from AppTheme.weather
            baseTop = isDark
                ? WidgetRGBColor(r: 0.082, g: 0.267, b: 0.451)
                : WidgetRGBColor(r: 0.816, g: 0.902, b: 0.984)
            baseBottom = isDark
                ? WidgetRGBColor(r: 0.031, g: 0.118, b: 0.235)
                : WidgetRGBColor(r: 0.941, g: 0.969, b: 0.996)

            condColors = Self.daytimeConditionColors(descriptor: descriptor, temp: temp, isDark: isDark)
            tintAmount = isDark ? 0.38 : 0.22
        }

        let finalTop = baseTop.mix(with: condColors.0, by: tintAmount)
        let finalBottom = baseBottom.mix(with: condColors.1, by: tintAmount)

        self.backgroundGradient = LinearGradient(
            colors: [finalTop.color, finalBottom.color],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )

        self.ambientHighlightColor = condColors.0.color.opacity(isDark ? 0.28 : 0.18)

        // Evaluate perceived luminance to dynamically adapt foreground elements
        let avgLuminance = (finalTop.luminance * 0.60 + finalBottom.luminance * 0.40)
        let lightMode = avgLuminance > 0.45
        self.isLight = lightMode

        if lightMode {
            // Deep, high-contrast slate & navy tones for light backgrounds
            self.textPrimary = Color(red: 0.06, green: 0.14, blue: 0.24)
            self.textSecondary = Color(red: 0.18, green: 0.30, blue: 0.44)
            self.textTertiary = Color(red: 0.30, green: 0.42, blue: 0.56)

            // Frosted glass cards on top of light background
            self.cardBackground = Color.white.opacity(0.55)
            self.cardBorder = Color.white.opacity(0.85)
            self.chipBackground = Color.white.opacity(0.60)
            self.chipBorder = Color(red: 0.06, green: 0.14, blue: 0.24).opacity(0.08)
            self.dividerColor = Color(red: 0.06, green: 0.14, blue: 0.24).opacity(0.12)

            self.locationTint = Color(red: 0.00, green: 0.46, blue: 0.88)
            self.rainChipBackground = Color.blue.opacity(0.18)
            self.rainChipText = Color(red: 0.02, green: 0.32, blue: 0.72)

            self.humidityTint = Color(red: 0.00, green: 0.52, blue: 0.82)
            self.windTint = Color(red: 0.02, green: 0.56, blue: 0.56)
            self.rainIconTint = Color(red: 0.02, green: 0.48, blue: 0.88)
            self.directionTint = Color(red: 0.90, green: 0.42, blue: 0.00)
        } else {
            // Crisp, glowing white & ice-blue tones for dark backgrounds
            self.textPrimary = Color.white
            self.textSecondary = Color.white.opacity(0.78)
            self.textTertiary = Color.white.opacity(0.60)

            self.cardBackground = Color.white.opacity(0.10)
            self.cardBorder = Color.white.opacity(0.14)
            self.chipBackground = Color.white.opacity(0.12)
            self.chipBorder = Color.white.opacity(0.16)
            self.dividerColor = Color.white.opacity(0.14)

            self.locationTint = Color.cyan
            self.rainChipBackground = Color.blue.opacity(0.35)
            self.rainChipText = Color.cyan

            self.humidityTint = Color.cyan
            self.windTint = Color.teal
            self.rainIconTint = Color.cyan
            self.directionTint = Color.orange
        }
    }

    init(entry: WidgetWeatherEntry, colorScheme: ColorScheme) {
        self.init(
            descriptor: entry.iconDescriptor,
            isNight: entry.isNight,
            temp: entry.temp,
            colorScheme: colorScheme
        )
    }

    private static func daytimeConditionColors(
        descriptor: String,
        temp: Double,
        isDark: Bool
    ) -> (WidgetRGBColor, WidgetRGBColor) {
        let desc = descriptor.lowercased()

        if temp >= 32 {
            return isDark
                ? (WidgetRGBColor(r: 0.55, g: 0.08, b: 0.06), WidgetRGBColor(r: 0.92, g: 0.27, b: 0.10))
                : (WidgetRGBColor(r: 1.00, g: 0.32, b: 0.20), WidgetRGBColor(r: 0.85, g: 0.10, b: 0.10))
        }

        if temp <= 5 {
            return isDark
                ? (WidgetRGBColor(r: 0.02, g: 0.18, b: 0.42), WidgetRGBColor(r: 0.10, g: 0.42, b: 0.78))
                : (WidgetRGBColor(r: 0.40, g: 0.74, b: 1.00), WidgetRGBColor(r: 0.10, g: 0.40, b: 0.85))
        }

        if desc.contains("storm") || desc.contains("thunder") || desc.contains("rain") || desc.contains("shower") {
            return isDark
                ? (WidgetRGBColor(r: 0.08, g: 0.12, b: 0.20), WidgetRGBColor(r: 0.18, g: 0.24, b: 0.34))
                : (WidgetRGBColor(r: 0.35, g: 0.45, b: 0.58), WidgetRGBColor(r: 0.18, g: 0.28, b: 0.42))
        }

        if desc.contains("partly") || desc.contains("mostly_sunny") {
            return isDark
                ? (WidgetRGBColor(r: 0.14, g: 0.32, b: 0.58), WidgetRGBColor(r: 0.32, g: 0.36, b: 0.42))
                : (WidgetRGBColor(r: 0.30, g: 0.62, b: 0.95), WidgetRGBColor(r: 0.62, g: 0.66, b: 0.72))
        }

        if desc.contains("cloudy") || desc.contains("overcast") {
            return isDark
                ? (WidgetRGBColor(r: 0.18, g: 0.20, b: 0.24), WidgetRGBColor(r: 0.34, g: 0.38, b: 0.42))
                : (WidgetRGBColor(r: 0.62, g: 0.64, b: 0.68), WidgetRGBColor(r: 0.40, g: 0.44, b: 0.48))
        }

        if desc.contains("hazy") || desc.contains("fog") || desc.contains("mist") {
            return isDark
                ? (WidgetRGBColor(r: 0.26, g: 0.28, b: 0.32), WidgetRGBColor(r: 0.42, g: 0.46, b: 0.50))
                : (WidgetRGBColor(r: 0.68, g: 0.72, b: 0.76), WidgetRGBColor(r: 0.50, g: 0.56, b: 0.62))
        }

        // Sunny / clear
        return isDark
            ? (WidgetRGBColor(r: 0.02, g: 0.22, b: 0.50), WidgetRGBColor(r: 0.08, g: 0.42, b: 0.78))
            : (WidgetRGBColor(r: 0.20, g: 0.62, b: 0.98), WidgetRGBColor(r: 0.06, g: 0.42, b: 0.88))
    }

    /// Palette foreground styles for multi-layer weather symbols (primary: cloud/body, secondary: sun/moon/rain)
    func symbolForeground(isNight: Bool) -> (primary: Color, secondary: Color) {
        if isLight {
            let secondary = isNight
                ? Color(red: 0.28, green: 0.42, blue: 0.78)
                : Color(red: 0.98, green: 0.58, blue: 0.00)
            let primary = Color(red: 0.34, green: 0.46, blue: 0.60)
            return (primary, secondary)
        } else {
            let secondary = isNight ? Color.cyan : Color.yellow
            return (Color.white, secondary)
        }
    }

    /// Color for single-layer hourly symbols
    func hourlySymbolColor(for descriptor: String, isNight: Bool) -> Color {
        let desc = descriptor.lowercased()
        if isLight {
            if desc.contains("storm") || desc.contains("thunder") {
                return Color(red: 0.52, green: 0.22, blue: 0.76)
            }
            if desc.contains("rain") || desc.contains("shower") {
                return Color(red: 0.02, green: 0.48, blue: 0.88)
            }
            if desc.contains("cloudy") {
                return Color(red: 0.36, green: 0.48, blue: 0.62)
            }
            if isNight {
                return Color(red: 0.28, green: 0.42, blue: 0.78)
            }
            return Color(red: 0.98, green: 0.56, blue: 0.00)
        } else {
            if desc.contains("storm") || desc.contains("thunder") {
                return Color.purple
            }
            if desc.contains("rain") || desc.contains("shower") {
                return Color.cyan
            }
            if desc.contains("cloudy") {
                return Color.white.opacity(0.85)
            }
            if isNight {
                return Color(red: 0.70, green: 0.75, blue: 1.0)
            }
            return Color.yellow
        }
    }
}

// MARK: - Widget Background

struct WidgetBackgroundView: View {
    let descriptor: String
    let isNight: Bool
    let temp: Double
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let theme = WidgetTheme(descriptor: descriptor, isNight: isNight, temp: temp, colorScheme: colorScheme)
        ZStack {
            theme.backgroundGradient
            RadialGradient(
                colors: [theme.ambientHighlightColor, .clear],
                center: .topTrailing,
                startRadius: 10,
                endRadius: 160
            )
        }
    }
}

// MARK: - Current Conditions Widget View

struct CurrentConditionsWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: WidgetWeatherEntry

    var body: some View {
        Group {
            switch family {
            case .systemSmall:
                SmallCurrentConditionsView(entry: entry)
            case .systemMedium:
                MediumCurrentConditionsView(entry: entry)
            case .accessoryCircular:
                AccessoryCircularConditionsView(entry: entry)
            case .accessoryRectangular:
                AccessoryRectangularConditionsView(entry: entry)
            case .accessoryInline:
                AccessoryInlineConditionsView(entry: entry)
            default:
                SmallCurrentConditionsView(entry: entry)
            }
        }
        .widgetURL(URL(string: "papaweather://station"))
    }
}

// MARK: - Small Current Conditions

private struct SmallCurrentConditionsView: View {
    let entry: WidgetWeatherEntry
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let theme = WidgetTheme(entry: entry, colorScheme: colorScheme)
        let (symPrimary, symSecondary) = theme.symbolForeground(isNight: entry.isNight)

        VStack(alignment: .leading, spacing: 6) {
            // Locality Header
            HStack(spacing: 4) {
                Image(systemName: "location.fill")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(theme.locationTint)
                Text(entry.locality)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(theme.textPrimary)
                    .lineLimit(1)
                Spacer(minLength: 0)
            }

            Spacer(minLength: 0)

            // Weather Symbol + Big Temperature
            HStack(alignment: .center, spacing: 8) {
                Image(systemName: entry.symbolName)
                    .font(.system(size: 34, weight: .medium))
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(symPrimary, symSecondary)
                    .frame(width: 36, height: 36)

                Text("\(Int(round(entry.temp)))°")
                    .font(.system(size: 38, weight: .light, design: .rounded))
                    .foregroundStyle(theme.textPrimary)
                    .monospacedDigit()
                    .lineLimit(1)
            }

            // Condition text
            Text(entry.conditionText)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(theme.textSecondary)
                .lineLimit(1)

            Spacer(minLength: 0)

            // Glanceable metrics chips
            HStack(spacing: 6) {
                HStack(spacing: 3) {
                    Image(systemName: "thermometer.medium")
                        .font(.system(size: 9))
                    Text("Feels \(Int(round(entry.apparentTemp)))°")
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                }
                .foregroundStyle(theme.textSecondary)
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(
                    Capsule().fill(theme.chipBackground)
                )
                .overlay(
                    Capsule().strokeBorder(theme.chipBorder, lineWidth: 0.5)
                )

                HStack(spacing: 3) {
                    Image(systemName: "drop.fill")
                        .font(.system(size: 9))
                    Text("\(entry.rainChance)%")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                }
                .foregroundStyle(entry.rainChance > 30 ? theme.rainChipText : theme.textSecondary)
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(
                    Capsule().fill(entry.rainChance > 30 ? theme.rainChipBackground : theme.chipBackground)
                )
                .overlay(
                    Capsule().strokeBorder(theme.chipBorder, lineWidth: 0.5)
                )

                Spacer(minLength: 0)
            }
        }
    }
}

// MARK: - Medium Current Conditions

private struct MediumCurrentConditionsView: View {
    let entry: WidgetWeatherEntry
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let theme = WidgetTheme(entry: entry, colorScheme: colorScheme)
        let (symPrimary, symSecondary) = theme.symbolForeground(isNight: entry.isNight)

        HStack(spacing: 14) {
            // Left Pane: Overview
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 4) {
                    Image(systemName: "location.fill")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(theme.locationTint)
                    Text(entry.locality)
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(theme.textPrimary)
                        .lineLimit(1)
                }

                Text(entry.stationName)
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(theme.textSecondary)
                    .lineLimit(1)

                Spacer(minLength: 0)

                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text("\(Int(round(entry.temp)))°C")
                        .font(.system(size: 38, weight: .light, design: .rounded))
                        .foregroundStyle(theme.textPrimary)
                        .monospacedDigit()
                        .lineLimit(1)

                    Image(systemName: entry.symbolName)
                        .font(.system(size: 28, weight: .medium))
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(symPrimary, symSecondary)
                }

                Text(entry.conditionText)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(theme.textPrimary)
                    .lineLimit(1)

                Text("Feels like \(Int(round(entry.apparentTemp)))°C")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(theme.textSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // Right Pane: 2x2 Glance Cards
            VStack(spacing: 6) {
                HStack(spacing: 6) {
                    metricCard(
                        icon: "humidity.fill",
                        iconColor: theme.humidityTint,
                        title: "Humidity",
                        value: "\(entry.humidity)%",
                        theme: theme
                    )
                    metricCard(
                        icon: "wind",
                        iconColor: theme.windTint,
                        title: "Wind",
                        value: "\(entry.windSpeedKmh) km/h",
                        theme: theme
                    )
                }
                HStack(spacing: 6) {
                    metricCard(
                        icon: "drop.fill",
                        iconColor: theme.rainIconTint,
                        title: "Rain Chance",
                        value: "\(entry.rainChance)%",
                        theme: theme
                    )
                    metricCard(
                        icon: "safari.fill",
                        iconColor: theme.directionTint,
                        title: "Direction",
                        value: entry.windDirection.isEmpty ? "Calm" : entry.windDirection,
                        theme: theme
                    )
                }
            }
            .frame(maxWidth: .infinity)
        }
    }

    private func metricCard(
        icon: String,
        iconColor: Color,
        title: String,
        value: String,
        theme: WidgetTheme
    ) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 10))
                    .foregroundStyle(iconColor)
                Text(title)
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundStyle(theme.textSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
            Text(value)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(theme.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 7)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(theme.cardBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(theme.cardBorder, lineWidth: 0.5)
        )
    }
}

// MARK: - Lock Screen / Accessory Views

private struct AccessoryCircularConditionsView: View {
    let entry: WidgetWeatherEntry

    var body: some View {
        VStack(spacing: 2) {
            Image(systemName: entry.symbolName)
                .font(.system(size: 16))
            Text("\(Int(round(entry.temp)))°")
                .font(.system(size: 14, weight: .semibold, design: .rounded))
        }
    }
}

private struct AccessoryRectangularConditionsView: View {
    let entry: WidgetWeatherEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 3) {
                Image(systemName: "location.fill")
                    .font(.system(size: 9))
                Text(entry.locality)
                    .font(.system(size: 11, weight: .bold))
                Spacer()
                Text("\(Int(round(entry.temp)))°")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
            }
            HStack(spacing: 4) {
                Image(systemName: entry.symbolName)
                    .font(.system(size: 11))
                Text(entry.conditionText)
                    .font(.system(size: 10))
                    .lineLimit(1)
            }
            HStack(spacing: 3) {
                Image(systemName: "drop.fill")
                    .font(.system(size: 8))
                Text("\(entry.rainChance)% rain")
                    .font(.system(size: 9))
                Text("• Feels \(Int(round(entry.apparentTemp)))°")
                    .font(.system(size: 9))
            }
            .foregroundStyle(.secondary)
        }
    }
}

private struct AccessoryInlineConditionsView: View {
    let entry: WidgetWeatherEntry

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: entry.symbolName)
            Text("\(entry.locality) \(Int(round(entry.temp)))° • \(entry.conditionText)")
        }
    }
}

// MARK: - Hourly Overview Widget View

struct HourlyOverviewWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: WidgetWeatherEntry

    var body: some View {
        Group {
            switch family {
            case .systemSmall:
                SmallHourlyOverviewView(entry: entry)
            case .systemMedium:
                MediumHourlyOverviewView(entry: entry)
            case .systemLarge:
                LargeHourlyOverviewView(entry: entry)
            default:
                MediumHourlyOverviewView(entry: entry)
            }
        }
        .widgetURL(URL(string: "papaweather://hourly"))
    }
}

// MARK: - Medium Hourly Overview

private struct MediumHourlyOverviewView: View {
    let entry: WidgetWeatherEntry
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let theme = WidgetTheme(entry: entry, colorScheme: colorScheme)

        VStack(alignment: .leading, spacing: 8) {
            // Header: Locality and "Next 6 Hours"
            HStack(alignment: .center) {
                HStack(spacing: 4) {
                    Image(systemName: "location.fill")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(theme.locationTint)
                    Text(entry.locality)
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(theme.textPrimary)
                        .lineLimit(1)
                }

                Spacer()

                Label("Next 6 Hours", systemImage: "clock.fill")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(theme.textSecondary)
            }

            Spacer(minLength: 0)

            // 6-Hour Horizontal Track
            let hours = Array(entry.hourlyForecast.prefix(6))
            HStack(spacing: 0) {
                ForEach(hours) { hour in
                    VStack(spacing: 5) {
                        Text(hour.time)
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                            .foregroundStyle(theme.textSecondary)

                        Image(systemName: hour.symbolName)
                            .font(.system(size: 18))
                            .foregroundStyle(theme.hourlySymbolColor(for: hour.iconDescriptor, isNight: hour.isNight))
                            .frame(height: 22)

                        Text("\(hour.temp)°")
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                            .foregroundStyle(theme.textPrimary)
                            .monospacedDigit()

                        HStack(spacing: 2) {
                            Image(systemName: "drop.fill")
                                .font(.system(size: 7))
                            Text("\(hour.rainChance)%")
                                .font(.system(size: 9, weight: .bold, design: .rounded))
                        }
                        .foregroundStyle(hour.rainChance > 30 ? theme.rainChipText : theme.textSecondary)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 2)
                        .background(
                            Capsule().fill(hour.rainChance > 30 ? theme.rainChipBackground : theme.chipBackground)
                        )
                        .overlay(
                            Capsule().strokeBorder(theme.chipBorder, lineWidth: 0.5)
                        )
                    }
                    .frame(maxWidth: .infinity)
                }
            }

            Spacer(minLength: 0)

            // Glanceable Rain Outlook Bar
            HStack(spacing: 6) {
                Image(systemName: "cloud.rain.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(theme.rainIconTint)
                Text(entry.rainOutlook)
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(theme.textSecondary)
                    .lineLimit(1)
                Spacer()
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(theme.cardBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(theme.cardBorder, lineWidth: 0.5)
            )
        }
    }
}

// MARK: - Small Hourly Overview

private struct SmallHourlyOverviewView: View {
    let entry: WidgetWeatherEntry
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let theme = WidgetTheme(entry: entry, colorScheme: colorScheme)

        VStack(alignment: .leading, spacing: 6) {
            // Header
            HStack(spacing: 4) {
                Image(systemName: "location.fill")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(theme.locationTint)
                Text(entry.locality)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(theme.textPrimary)
                    .lineLimit(1)
                Spacer(minLength: 0)
            }

            Text("Hourly Overview")
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .foregroundStyle(theme.textSecondary)

            Spacer(minLength: 0)

            // 3 milestone rows
            let hours = Array(entry.hourlyForecast.prefix(3))
            VStack(spacing: 6) {
                ForEach(hours) { hour in
                    HStack(spacing: 6) {
                        Text(hour.time)
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundStyle(theme.textSecondary)
                            .frame(width: 38, alignment: .leading)

                        Image(systemName: hour.symbolName)
                            .font(.system(size: 14))
                            .foregroundStyle(theme.hourlySymbolColor(for: hour.iconDescriptor, isNight: hour.isNight))
                            .frame(width: 18)

                        Text("\(hour.temp)°")
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .foregroundStyle(theme.textPrimary)
                            .monospacedDigit()

                        Spacer()

                        HStack(spacing: 2) {
                            Image(systemName: "drop.fill").font(.system(size: 7))
                            Text("\(hour.rainChance)%").font(.system(size: 9, weight: .bold, design: .rounded))
                        }
                        .foregroundStyle(hour.rainChance > 30 ? theme.rainChipText : theme.textSecondary)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(
                            Capsule().fill(hour.rainChance > 30 ? theme.rainChipBackground : theme.chipBackground)
                        )
                        .overlay(
                            Capsule().strokeBorder(theme.chipBorder, lineWidth: 0.5)
                        )
                    }
                }
            }

            Spacer(minLength: 0)
        }
    }
}

// MARK: - Large Hourly Overview

private struct LargeHourlyOverviewView: View {
    let entry: WidgetWeatherEntry
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let theme = WidgetTheme(entry: entry, colorScheme: colorScheme)
        let (symPrimary, symSecondary) = theme.symbolForeground(isNight: entry.isNight)

        VStack(alignment: .leading, spacing: 10) {
            // Header: Locality & current condition
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 4) {
                        Image(systemName: "location.fill")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(theme.locationTint)
                        Text(entry.locality)
                            .font(.system(size: 17, weight: .bold, design: .rounded))
                            .foregroundStyle(theme.textPrimary)
                    }
                    Text(entry.stationName)
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(theme.textSecondary)
                }

                Spacer()

                HStack(spacing: 8) {
                    Image(systemName: entry.symbolName)
                        .font(.system(size: 28, weight: .medium))
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(symPrimary, symSecondary)

                    Text("\(Int(round(entry.temp)))°C")
                        .font(.system(size: 28, weight: .light, design: .rounded))
                        .foregroundStyle(theme.textPrimary)
                        .monospacedDigit()
                }
            }

            Divider().overlay(theme.dividerColor)

            // Progression
            Label("Next 6 Hours", systemImage: "clock.fill")
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(theme.textSecondary)

            let hours = Array(entry.hourlyForecast.prefix(6))
            HStack(spacing: 0) {
                ForEach(hours) { hour in
                    VStack(spacing: 5) {
                        Text(hour.time)
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                            .foregroundStyle(theme.textSecondary)

                        Image(systemName: hour.symbolName)
                            .font(.system(size: 18))
                            .foregroundStyle(theme.hourlySymbolColor(for: hour.iconDescriptor, isNight: hour.isNight))
                            .frame(height: 22)

                        Text("\(hour.temp)°")
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                            .foregroundStyle(theme.textPrimary)

                        HStack(spacing: 2) {
                            Image(systemName: "drop.fill").font(.system(size: 7))
                            Text("\(hour.rainChance)%").font(.system(size: 9, weight: .bold, design: .rounded))
                        }
                        .foregroundStyle(hour.rainChance > 30 ? theme.rainChipText : theme.textSecondary)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 2)
                        .background(
                            Capsule().fill(hour.rainChance > 30 ? theme.rainChipBackground : theme.chipBackground)
                        )
                        .overlay(
                            Capsule().strokeBorder(theme.chipBorder, lineWidth: 0.5)
                        )
                    }
                    .frame(maxWidth: .infinity)
                }
            }

            Divider().overlay(theme.dividerColor)

            // Outlook Cards
            HStack(spacing: 10) {
                summaryCard(
                    icon: "cloud.rain.fill",
                    iconColor: theme.rainIconTint,
                    title: "Rain Outlook",
                    description: entry.rainOutlook,
                    theme: theme
                )
                summaryCard(
                    icon: "wind",
                    iconColor: theme.windTint,
                    title: "Wind Outlook",
                    description: entry.peakWindOutlook,
                    theme: theme
                )
            }
        }
    }

    private func summaryCard(
        icon: String,
        iconColor: Color,
        title: String,
        description: String,
        theme: WidgetTheme
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 11))
                    .foregroundStyle(iconColor)
                Text(title)
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(theme.textSecondary)
            }
            Text(description)
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(theme.textPrimary)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(theme.cardBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(theme.cardBorder, lineWidth: 0.5)
        )
    }
}
