//
//  HourlyTabView.swift
//  papaWeather
//

import SwiftUI

struct HourlyTabView: View {
    let hourly: HourlyForecastInfo?

    var body: some View {
        if let hourly {
            VStack(spacing: 16) {
                if let current = hourly.current {
                    currentConditionsCard(current)
                }
                if !hourly.hours.isEmpty {
                    hourlyScrollCard(hourly.hours)
                }
                if !hourly.hours.isEmpty {
                    windScrollCard(hourly.hours)
                }
                if !hourly.hours.isEmpty {
                    feelsLikeScrollCard(hourly.hours)
                }
            }
        } else {
            emptyState
        }
    }

    // MARK: - Current conditions card

    private func currentConditionsCard(_ hour: HourlyForecastHour) -> some View {
        CardContainer {
            VStack(alignment: .leading, spacing: 14) {
                Label("Current Conditions", systemImage: "clock.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)

                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(alignment: .firstTextBaseline, spacing: 2) {
                            Text("\(hour.temp)")
                                .font(.system(size: 52, weight: .thin))
                            Text("°C")
                                .font(.title3)
                                .foregroundStyle(.secondary)
                                .padding(.top, 8)
                        }
                        Text("Feels like \(hour.feelsLike)°")
                            .font(.body)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Image(systemName: symbol(for: hour))
                        .font(.system(size: 52))
                        .symbolRenderingMode(.multicolor)
                }

                Divider()

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                    statCell(icon: "drop.fill",      color: .blue,   label: "Rain Chance",  value: "\(hour.rainChance)%")
                    statCell(icon: "humidity.fill",  color: .teal,   label: "Humidity",     value: "\(hour.relativeHumidity)%")
                    statCell(icon: "wind",           color: .gray,   label: "Wind",         value: "\(hour.windDirection) \(hour.windSpeedKmh) km/h")
                    statCell(icon: "tornado",        color: .secondary, label: "Gusts",     value: "\(hour.gustSpeedKmh) km/h")
                }
            }
        }
    }

    private func statCell(icon: String, color: Color, label: String, value: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 13))
                .foregroundStyle(color)
                .frame(width: 18)
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.subheadline.weight(.semibold))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(Color.secondary.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    // MARK: - Hourly scroll card (tap to expand)

    @State private var selectedHourId: UUID?

    private func hourlyScrollCard(_ hours: [HourlyForecastHour]) -> some View {
        CardContainer {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Label("Hourly Overview", systemImage: "clock.arrow.2.circlepath")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Label("Tap for details", systemImage: "hand.tap")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }

                Divider()

                let allMin = hours.map(\.temp).min() ?? 0
                let allMax = hours.map(\.temp).max() ?? 40
                let groups = groupByDay(hours)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(alignment: .top, spacing: 0) {
                        ForEach(groups, id: \.label) { group in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(group.label)
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(.secondary)
                                    .padding(.leading, 6)

                                HStack(alignment: .top, spacing: 2) {
                                    ForEach(group.hours) { hour in
                                        HourColumn(
                                            hour: hour,
                                            allMin: allMin,
                                            allMax: allMax,
                                            isSelected: selectedHourId == hour.id
                                        )
                                        .onTapGesture {
                                            withAnimation(.spring(duration: 0.25)) {
                                                selectedHourId = selectedHourId == hour.id ? nil : hour.id
                                            }
                                        }
                                    }
                                }
                            }

                            if group.label != groups.last?.label {
                                Divider()
                                    .frame(height: 90)
                                    .padding(.horizontal, 4)
                                    .padding(.top, 20)
                            }
                        }
                    }
                    .padding(.horizontal, 2)
                }

                if let id = selectedHourId, let hour = hours.first(where: { $0.id == id }) {
                    Divider()
                    HourSelectedDetail(hour: hour)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
        }
    }

    // MARK: - Wind speed scroll card

    private func windScrollCard(_ hours: [HourlyForecastHour]) -> some View {
        CardContainer {
            VStack(alignment: .leading, spacing: 12) {
                Label("Hourly Wind", systemImage: "wind")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)

                Divider()

                let maxWind = max(hours.map(\.gustSpeedKmh).max() ?? 1, 1)
                let groups = groupByDay(hours)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(alignment: .top, spacing: 0) {
                        ForEach(groups, id: \.label) { group in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(group.label)
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(.secondary)
                                    .padding(.leading, 6)

                                HStack(alignment: .top, spacing: 2) {
                                    ForEach(group.hours) { hour in
                                        WindColumn(hour: hour, maxWind: maxWind)
                                    }
                                }
                            }

                            if group.label != groups.last?.label {
                                Divider()
                                    .frame(height: 90)
                                    .padding(.horizontal, 4)
                                    .padding(.top, 20)
                            }
                        }
                    }
                    .padding(.horizontal, 2)
                }
            }
        }
    }

    // MARK: - Feels Like scroll card

    private func feelsLikeScrollCard(_ hours: [HourlyForecastHour]) -> some View {
        CardContainer {
            VStack(alignment: .leading, spacing: 12) {
                Label("Feels Like", systemImage: "thermometer.medium")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)

                Divider()

                let allMin = min(hours.map(\.feelsLike).min() ?? 0, hours.map(\.temp).min() ?? 0)
                let allMax = max(hours.map(\.feelsLike).max() ?? 40, hours.map(\.temp).max() ?? 40)
                let groups = groupByDay(hours)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(alignment: .top, spacing: 0) {
                        ForEach(groups, id: \.label) { group in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(group.label)
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(.secondary)
                                    .padding(.leading, 6)

                                HStack(alignment: .top, spacing: 2) {
                                    ForEach(group.hours) { hour in
                                        FeelsLikeColumn(hour: hour, allMin: allMin, allMax: allMax)
                                    }
                                }
                            }

                            if group.label != groups.last?.label {
                                Divider()
                                    .frame(height: 90)
                                    .padding(.horizontal, 4)
                                    .padding(.top, 20)
                            }
                        }
                    }
                    .padding(.horizontal, 2)
                }
            }
        }
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "clock.badge.xmark")
                .font(.system(size: 40))
                .foregroundStyle(.secondary)
            Text("No hourly forecast available")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 60)
    }

    // MARK: - Day grouping

    private struct DayGroup {
        let label: String
        let hours: [HourlyForecastHour]
    }

    private func groupByDay(_ hours: [HourlyForecastHour]) -> [DayGroup] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        var result: [DayGroup] = []
        var seen: [Date: [HourlyForecastHour]] = [:]
        var order: [Date] = []

        for hour in hours {
            let day = cal.startOfDay(for: hour.rawDate)
            if seen[day] == nil {
                seen[day] = []
                order.append(day)
            }
            seen[day]!.append(hour)
        }

        let dayFmt = DateFormatter()
        dayFmt.dateFormat = "EEEE, d MMM"

        for day in order {
            let label: String
            if cal.isDate(day, inSameDayAs: today) {
                label = "Today"
            } else if let tomorrow = cal.date(byAdding: .day, value: 1, to: today),
                      cal.isDate(day, inSameDayAs: tomorrow) {
                label = "Tomorrow"
            } else {
                label = dayFmt.string(from: day)
            }
            result.append(DayGroup(label: label, hours: seen[day]!))
        }
        return result
    }

    // MARK: - Icon helpers

    private func symbol(for hour: HourlyForecastHour) -> String {
        let desc = hour.iconDescriptor.lowercased()
        if desc.contains("storm") || desc.contains("thunder")        { return "cloud.bolt.rain.fill" }
        if desc.contains("shower") || desc.contains("rain")          { return "cloud.rain.fill" }
        if desc.contains("cloudy") && hour.isNight                   { return "cloud.moon.fill" }
        if desc.contains("cloudy")                                   { return "cloud.fill" }
        if desc.contains("partly") || desc.contains("mostly_sunny") {
            return hour.isNight ? "cloud.moon.fill" : "cloud.sun.fill"
        }
        if desc.contains("hazy") || desc.contains("fog")             { return "cloud.fog.fill" }
        return hour.isNight ? "moon.stars.fill" : "sun.max.fill"
    }

    private func symbolColor(for hour: HourlyForecastHour) -> Color {
        let desc = hour.iconDescriptor.lowercased()
        if desc.contains("storm")                            { return .purple }
        if desc.contains("rain") || desc.contains("shower") { return .blue }
        if desc.contains("cloudy")                          { return .gray }
        if hour.isNight                                     { return .indigo }
        return .orange
    }
}

// MARK: - Hour column

private struct HourColumn: View {
    let hour: HourlyForecastHour
    let allMin: Int
    let allMax: Int
    let isSelected: Bool

    var body: some View {
        VStack(spacing: 5) {
            Text(hour.time)
                .font(.caption.weight(.semibold))
                .foregroundStyle(isSelected ? .primary : .secondary)

            Image(systemName: conditionSymbol)
                .font(.system(size: 20))
                .symbolRenderingMode(.multicolor)
                .frame(height: 24)

            Group {
                if hour.rainChance > 10 {
                    Text("\(hour.rainChance)%").foregroundStyle(.blue)
                } else {
                    Text(" ")
                }
            }
            .font(.caption)

            HourTempDot(temp: hour.temp, allMin: allMin, allMax: allMax)
                .frame(width: 8, height: 44)

            Text("\(hour.temp)°")
                .font(.caption.weight(.semibold))

            Image(systemName: isSelected ? "chevron.up" : "chevron.down")
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(.tertiary)
        }
        .frame(minWidth: 46)
        .padding(.vertical, 8)
        .padding(.horizontal, 4)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(isSelected ? Color.accentColor.opacity(0.12) : Color.clear)
        )
    }

    private var conditionSymbol: String {
        let desc = hour.iconDescriptor.lowercased()
        if desc.contains("storm") || desc.contains("thunder") { return "cloud.bolt.rain.fill" }
        if desc.contains("shower") || desc.contains("rain")   { return "cloud.rain.fill" }
        if desc.contains("cloudy") && hour.isNight            { return "cloud.moon.fill" }
        if desc.contains("cloudy")                            { return "cloud.fill" }
        if desc.contains("partly") || desc.contains("mostly_sunny") {
            return hour.isNight ? "cloud.moon.fill" : "cloud.sun.fill"
        }
        if desc.contains("hazy") || desc.contains("fog")     { return "cloud.fog.fill" }
        return hour.isNight ? "moon.stars.fill" : "sun.max.fill"
    }
}

// MARK: - Temperature position dot

private struct HourTempDot: View {
    let temp: Int
    let allMin: Int
    let allMax: Int

    var body: some View {
        GeometryReader { geo in
            let range = max(Double(allMax - allMin), 1)
            let normalized = Double(temp - allMin) / range  // 0 = coldest, 1 = warmest
            let h = geo.size.height
            let dotSize: CGFloat = 8
            let dotY = max(0, min(h * (1.0 - normalized) - dotSize / 2, h - dotSize))

            ZStack(alignment: .top) {
                // Gradient track: orange at top (hot), blue at bottom (cold)
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [.orange, .yellow, .cyan, .blue],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .opacity(0.25)

                // Dot indicating this hour's temperature
                Circle()
                    .fill(
                        LinearGradient(
                            colors: normalized > 0.5 ? [.orange, .yellow] : [.cyan, .blue],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: dotSize, height: dotSize)
                    .offset(y: dotY)
            }
        }
    }
}

// MARK: - Expanded hour detail

private struct HourSelectedDetail: View {
    let hour: HourlyForecastHour

    private let dateFmt: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "h:mm a, EEEE d MMM"
        return f
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text(dateFmt.string(from: hour.rawDate))
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text("\(hour.temp)°C")
                    .font(.subheadline.weight(.semibold))
            }

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                detailPill(symbol: "thermometer.medium",  color: .orange, label: "Feels like",  value: "\(hour.feelsLike)°C")
                detailPill(symbol: "drop.fill",           color: .blue,   label: "Rain chance", value: "\(hour.rainChance)%")
                detailPill(symbol: "wind",                color: .teal,   label: "Wind",        value: "\(hour.windDirection) \(hour.windSpeedKmh) km/h")
                detailPill(symbol: "tornado",             color: .gray,   label: "Gusts",       value: "\(hour.gustSpeedKmh) km/h")
                detailPill(symbol: "humidity.fill",       color: .cyan,   label: "Humidity",    value: "\(hour.relativeHumidity)%")
            }
        }
    }

    private func detailPill(symbol: String, color: Color, label: String, value: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: symbol)
                .font(.system(size: 13))
                .foregroundStyle(color)
                .frame(width: 18)
            VStack(alignment: .leading, spacing: 1) {
                Text(label)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.subheadline.weight(.semibold))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(Color.secondary.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

// MARK: - Wind column

private struct WindColumn: View {
    let hour: HourlyForecastHour
    let maxWind: Int

    var body: some View {
        VStack(spacing: 5) {
            Text(hour.time)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            Image(systemName: "arrow.up")
                .font(.system(size: 11, weight: .bold))
                .rotationEffect(.degrees(directionDegrees(hour.windDirection)))
                .foregroundStyle(.teal)
                .frame(height: 16)

            WindBar(windSpeed: hour.windSpeedKmh, gustSpeed: hour.gustSpeedKmh, maxWind: maxWind)
                .frame(width: 8, height: 44)

            Text("\(hour.windSpeedKmh)")
                .font(.caption.weight(.semibold))

            Text("km/h")
                .font(.system(size: 8))
                .foregroundStyle(.secondary)
        }
        .frame(minWidth: 46)
        .padding(.vertical, 8)
        .padding(.horizontal, 4)
    }

    // Arrow points toward the direction the wind comes FROM (meteorological convention)
    private func directionDegrees(_ dir: String) -> Double {
        switch dir.uppercased() {
        case "N":   return 0
        case "NNE": return 22.5
        case "NE":  return 45
        case "ENE": return 67.5
        case "E":   return 90
        case "ESE": return 112.5
        case "SE":  return 135
        case "SSE": return 157.5
        case "S":   return 180
        case "SSW": return 202.5
        case "SW":  return 225
        case "WSW": return 247.5
        case "W":   return 270
        case "WNW": return 292.5
        case "NW":  return 315
        case "NNW": return 337.5
        default:    return 0
        }
    }
}

// MARK: - Wind bar

private struct WindBar: View {
    let windSpeed: Int
    let gustSpeed: Int
    let maxWind: Int

    var body: some View {
        GeometryReader { geo in
            let h = geo.size.height
            let windH = max(4, h * Double(windSpeed) / Double(max(maxWind, 1)))
            let gustH = max(4, h * Double(gustSpeed) / Double(max(maxWind, 1)))

            ZStack(alignment: .bottom) {
                Capsule()
                    .fill(windColor(for: gustSpeed).opacity(0.20))
                    .frame(height: gustH)

                Capsule()
                    .fill(LinearGradient(
                        colors: windGradient(for: windSpeed),
                        startPoint: .top,
                        endPoint: .bottom
                    ))
                    .frame(height: windH)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        }
    }

    private func windColor(for speed: Int) -> Color {
        switch speed {
        case 0..<20:  return .teal
        case 20..<40: return .yellow
        case 40..<60: return .orange
        default:      return .red
        }
    }

    private func windGradient(for speed: Int) -> [Color] {
        switch speed {
        case 0..<20:  return [.cyan, .teal]
        case 20..<40: return [.yellow, .orange]
        case 40..<60: return [.orange, .red]
        default:      return [.red, .pink]
        }
    }
}

// MARK: - Feels like column

private struct FeelsLikeColumn: View {
    let hour: HourlyForecastHour
    let allMin: Int
    let allMax: Int

    var body: some View {
        VStack(spacing: 5) {
            Text(hour.time)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            Text("\(hour.temp)°")
                .font(.caption)
                .foregroundStyle(.tertiary)

            FeelsLikeDot(feelsLike: hour.feelsLike, temp: hour.temp, allMin: allMin, allMax: allMax)
                .frame(width: 8, height: 44)

            Text("\(hour.feelsLike)°")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.purple)

            Text("feels")
                .font(.system(size: 8))
                .foregroundStyle(.secondary)
        }
        .frame(minWidth: 46)
        .padding(.vertical, 8)
        .padding(.horizontal, 4)
    }
}

// MARK: - Feels like dot

private struct FeelsLikeDot: View {
    let feelsLike: Int
    let temp: Int
    let allMin: Int
    let allMax: Int

    var body: some View {
        GeometryReader { geo in
            let range = max(Double(allMax - allMin), 1)
            let normalizedFL = Double(feelsLike - allMin) / range
            let normalizedT  = Double(temp - allMin) / range
            let h = geo.size.height
            let dotSize: CGFloat = 8
            let smallDot: CGFloat = 5

            let flY  = max(0, min(h * (1.0 - normalizedFL) - dotSize / 2, h - dotSize))
            let tmpY = max(0, min(h * (1.0 - normalizedT)  - smallDot / 2, h - smallDot))

            ZStack(alignment: .top) {
                Capsule()
                    .fill(LinearGradient(
                        colors: [.purple, .indigo, .blue],
                        startPoint: .top,
                        endPoint: .bottom
                    ))
                    .opacity(0.20)

                // Actual temp dot (small, neutral)
                Circle()
                    .fill(Color.secondary.opacity(0.45))
                    .frame(width: smallDot, height: smallDot)
                    .offset(x: 1.5, y: tmpY)

                // Feels-like dot (prominent, purple/indigo)
                Circle()
                    .fill(LinearGradient(
                        colors: normalizedFL > 0.5 ? [.orange, .pink] : [.purple, .indigo],
                        startPoint: .top,
                        endPoint: .bottom
                    ))
                    .frame(width: dotSize, height: dotSize)
                    .offset(y: flY)
            }
        }
    }
}
