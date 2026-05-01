//
//  ForecastCard.swift
//  papaWeather
//

import SwiftUI
import Charts

struct ForecastCard: View {
    let forecast: DailyForecastInfo?
    let debugSummary: String

    @State private var selectedDayId: String?

    private var days: [DailyForecastDay] { forecast.map { Array($0.days.prefix(7)) } ?? [] }
    private var weekMin: Int { days.compactMap(\.tempMin).min() ?? 0 }
    private var weekMax: Int { days.compactMap(\.tempMax).max() ?? 40 }

    var body: some View {
        CardContainer {
            VStack(alignment: .leading, spacing: 12) {
                Label("7-Day Forecast", systemImage: "calendar")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)

                if let forecast {
                    Text(forecast.locationName)
                        .font(.body.weight(.medium))

                    Divider()

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(alignment: .top, spacing: 2) {
                            ForEach(days) { day in
                                ForecastDayColumn(
                                    day: day,
                                    weekMin: weekMin,
                                    weekMax: weekMax,
                                    isSelected: selectedDayId == day.id
                                )
                                .onTapGesture {
                                    withAnimation(.spring(duration: 0.25)) {
                                        selectedDayId = selectedDayId == day.id ? nil : day.id
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 2)
                    }

                    if days.contains(where: { $0.rainChancePercent != nil }) {
                        Divider()
                        rainChanceChart
                    }

                    if days.contains(where: { $0.sunriseDate != nil }) {
                        Divider()
                        daylightChart
                    }

                    if let id = selectedDayId, let day = days.first(where: { $0.id == id }) {
                        Divider()
                        ForecastSelectedDayDetail(day: day)
                            .transition(.opacity.combined(with: .move(edge: .top)))
                    }

                } else {
                    Text(debugSummary)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                DisclosureGroup("Debug summary") {
                    Text(debugSummary)
                        .font(.caption.monospaced())
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .textSelection(.enabled)
                        .padding(.top, 6)
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
    }

    private var rainChanceChart: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Rain chance (%)")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tertiary)

            Chart {
                ForEach(days) { day in
                    BarMark(
                        x: .value("Day", shortDayLabel(day.date)),
                        y: .value("Chance", day.rainChancePercent ?? 0)
                    )
                    .foregroundStyle(rainBarColor(for: day.rainChancePercent ?? 0))
                    .cornerRadius(4)
                }
                RuleMark(y: .value("50%", 50))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 3]))
                    .foregroundStyle(.blue.opacity(0.4))
                    .annotation(position: .leading) {
                        Text("50").font(.caption).foregroundStyle(.blue.opacity(0.4))
                    }
            }
            .chartYScale(domain: 0...100)
            .chartYAxis {
                AxisMarks(values: [0, 50, 100]) { value in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                    AxisValueLabel {
                        if let v = value.as(Int.self) { Text("\(v)%").font(.caption) }
                    }
                }
            }
            .chartXAxis {
                AxisMarks { _ in AxisValueLabel().font(.caption) }
            }
            .frame(height: 80)
        }
    }

    private func rainBarColor(for chance: Int) -> LinearGradient {
        let opacity = 0.3 + 0.7 * Double(chance) / 100
        return LinearGradient(colors: [.blue.opacity(opacity), .blue.opacity(opacity * 0.6)],
                              startPoint: .top, endPoint: .bottom)
    }

    private var daylightChart: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 12) {
                Label("Sunrise", systemImage: "sunrise.fill")
                    .foregroundStyle(.orange)
                Label("Sunset", systemImage: "sunset.fill")
                    .foregroundStyle(.indigo)
            }
            .font(.caption.weight(.semibold))
            .foregroundStyle(.tertiary)

            Chart {
                ForEach(days) { day in
                    if let rise = day.sunriseDate, let set = day.sunsetDate {
                        BarMark(
                            x: .value("Day", shortDayLabel(day.date)),
                            yStart: .value("Sunrise", hoursFromMidnight(rise)),
                            yEnd:   .value("Sunset",  hoursFromMidnight(set))
                        )
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.orange.opacity(0.7), .yellow.opacity(0.5), .indigo.opacity(0.6)],
                                startPoint: .bottom, endPoint: .top
                            )
                        )
                        .cornerRadius(4)

                        PointMark(
                            x: .value("Day", shortDayLabel(day.date)),
                            y: .value("Sunrise", hoursFromMidnight(rise))
                        )
                        .foregroundStyle(.orange)
                        .symbolSize(30)

                        PointMark(
                            x: .value("Day", shortDayLabel(day.date)),
                            y: .value("Sunset", hoursFromMidnight(set))
                        )
                        .foregroundStyle(.indigo)
                        .symbolSize(30)
                    }
                }
            }
            .chartYScale(domain: 4.0...21.0)
            .chartYAxis {
                AxisMarks(values: [6.0, 12.0, 18.0]) { value in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                    AxisValueLabel {
                        if let v = value.as(Double.self) {
                            Text(hourLabel(v)).font(.caption)
                        }
                    }
                }
            }
            .chartXAxis {
                AxisMarks { _ in AxisValueLabel().font(.caption) }
            }
            .frame(height: 100)
        }
    }

    private func hoursFromMidnight(_ date: Date) -> Double {
        let cal = Calendar.current
        let c = cal.dateComponents([.hour, .minute], from: date)
        return Double(c.hour ?? 0) + Double(c.minute ?? 0) / 60.0
    }

    private func hourLabel(_ hours: Double) -> String {
        let h = Int(hours)
        if h == 0 || h == 24 { return "12 AM" }
        if h == 12 { return "12 PM" }
        return h < 12 ? "\(h) AM" : "\(h - 12) PM"
    }

    private func shortDayLabel(_ isoDate: String) -> String {
        let inFmt = DateFormatter()
        inFmt.locale = Locale(identifier: "en_US_POSIX")
        inFmt.dateFormat = "yyyy-MM-dd"
        let outFmt = DateFormatter()
        outFmt.dateFormat = "EEE"
        if let d = inFmt.date(from: isoDate) { return outFmt.string(from: d) }
        return String(isoDate.prefix(3))
    }
}

// MARK: - Forecast Day Column

private struct ForecastDayColumn: View {
    let day: DailyForecastDay
    let weekMin: Int
    let weekMax: Int
    let isSelected: Bool

    var body: some View {
        VStack(spacing: 5) {
            Text(shortDayName)
                .font(.caption.weight(.semibold))
                .foregroundStyle(isSelected ? .primary : .secondary)

            Image(systemName: conditionSymbol)
                .font(.system(size: 20))
                .symbolRenderingMode(.multicolor)
                .frame(height: 24)

            Group {
                if let rain = day.rainChancePercent, rain > 10 {
                    Text("\(rain)%").foregroundStyle(.blue)
                } else {
                    Text(" ")
                }
            }
            .font(.caption)

            TempRangeBar(tempMin: day.tempMin, tempMax: day.tempMax,
                         weekMin: weekMin, weekMax: weekMax)
                .frame(width: 6, height: 44)

            VStack(spacing: 1) {
                Text(day.tempMax.map { "\($0)°" } ?? "--")
                    .font(.caption.weight(.semibold))
                Text(day.tempMin.map { "\($0)°" } ?? "--")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(minWidth: 46)
        .padding(.vertical, 8)
        .padding(.horizontal, 4)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(isSelected ? Color.accentColor.opacity(0.12) : Color.clear)
        )
    }

    private var shortDayName: String {
        let inFmt = DateFormatter()
        inFmt.locale = Locale(identifier: "en_US_POSIX")
        inFmt.dateFormat = "yyyy-MM-dd"
        let outFmt = DateFormatter()
        outFmt.dateFormat = "EEE"
        if let d = inFmt.date(from: day.date) { return outFmt.string(from: d) }
        return day.date
    }

    private var conditionSymbol: String {
        let text = day.shortText?.lowercased() ?? ""
        if text.contains("storm") || text.contains("thunder") { return "cloud.bolt.rain.fill" }
        if text.contains("shower")                             { return "cloud.rain.fill" }
        if text.contains("rain") || text.contains("drizzle")  { return "cloud.drizzle.fill" }
        if text.contains("snow")                               { return "snowflake" }
        if text.contains("fog") || text.contains("mist")      { return "cloud.fog.fill" }
        if text.contains("partly")                             { return "cloud.sun.fill" }
        if text.contains("overcast") || text.contains("cloud"){ return "cloud.fill" }
        if text.contains("sunny") || text.contains("fine") || text.contains("clear") { return "sun.max.fill" }
        if let rain = day.rainChancePercent {
            if rain >= 70 { return "cloud.rain.fill" }
            if rain >= 40 { return "cloud.sun.rain.fill" }
        }
        return "sun.max.fill"
    }
}

// MARK: - Vertical temperature range bar

private struct TempRangeBar: View {
    let tempMin: Int?
    let tempMax: Int?
    let weekMin: Int
    let weekMax: Int

    var body: some View {
        GeometryReader { geo in
            let range  = max(Double(weekMax - weekMin), 1)
            let lo     = Double((tempMin ?? weekMin) - weekMin) / range
            let hi     = Double((tempMax ?? weekMax) - weekMin) / range
            let h      = geo.size.height
            let topGap = h * (1.0 - hi)
            let barH   = max(h * (hi - lo), 4.0)

            ZStack(alignment: .top) {
                Capsule().fill(Color.secondary.opacity(0.15))
                Capsule()
                    .fill(LinearGradient(colors: [.orange, .blue],
                                        startPoint: .top, endPoint: .bottom))
                    .frame(height: barH)
                    .offset(y: topGap)
            }
        }
    }
}

// MARK: - Expanded day detail

private struct ForecastSelectedDayDetail: View {
    let day: DailyForecastDay

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(formattedDay(day.date)).font(.subheadline.weight(.semibold))
                Spacer()
                Text(temperatureText).font(.subheadline.weight(.semibold))
            }

            if let text = day.shortText?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty {
                Text(text).font(.caption).foregroundStyle(.primary)
            }

            HStack(spacing: 10) {
                StatPill(label: "Rain", value: rainText, symbol: "cloud.rain.fill")
                if let uv = day.uvCategory?.trimmingCharacters(in: .whitespacesAndNewlines), !uv.isEmpty {
                    StatPill(label: "UV", value: uv, symbol: "sun.max.fill")
                }
                if let fire = day.fireDanger?.trimmingCharacters(in: .whitespacesAndNewlines), !fire.isEmpty {
                    StatPill(label: "Fire", value: fire, symbol: "flame.fill")
                }
            }

            if day.sunriseDate != nil || day.sunsetDate != nil {
                HStack(spacing: 10) {
                    if let rise = day.sunriseDate {
                        StatPill(label: "Sunrise", value: formatSunTime(rise), symbol: "sunrise.fill")
                    }
                    if let set = day.sunsetDate {
                        StatPill(label: "Sunset", value: formatSunTime(set), symbol: "sunset.fill")
                    }
                }
            }

            if let detail = day.extendedText?.trimmingCharacters(in: .whitespacesAndNewlines), !detail.isEmpty {
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var temperatureText: String {
        switch (day.tempMin, day.tempMax) {
        case let (min?, max?): return "\(min)-\(max)°C"
        case let (nil, max?): return "max \(max)°C"
        case let (min?, nil): return "min \(min)°C"
        case (nil, nil): return "n/a"
        }
    }

    private var rainText: String {
        let chance = day.rainChancePercent.map { "\($0)%" } ?? "n/a"
        guard let min = day.rainAmountMinMm else { return chance }
        guard let max = day.rainAmountMaxMm else {
            return min > 0 ? "\(chance) (\(min)mm)" : chance
        }
        if max > 0 { return "\(chance) (\(min)-\(max)mm)" }
        return chance
    }

    private func formattedDay(_ isoDate: String) -> String {
        let inFmt = DateFormatter()
        inFmt.calendar = Calendar(identifier: .gregorian)
        inFmt.locale = Locale(identifier: "en_US_POSIX")
        inFmt.dateFormat = "yyyy-MM-dd"
        let outFmt = DateFormatter()
        outFmt.calendar = Calendar.current
        outFmt.locale = Locale.current
        outFmt.dateFormat = "EEEE d MMM"
        if let d = inFmt.date(from: isoDate) { return outFmt.string(from: d) }
        return isoDate
    }

    private func formatSunTime(_ date: Date) -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = "h:mm a"
        fmt.timeZone = .current
        return fmt.string(from: date)
    }
}

private struct StatPill: View {
    let label: String
    let value: String
    let symbol: String

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: symbol)
            Text("\(label): \(value)")
        }
        .font(.caption)
        .foregroundStyle(.secondary)
    }
}
