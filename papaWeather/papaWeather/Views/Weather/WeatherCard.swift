//
//  WeatherCard.swift
//  papaWeather
//

import SwiftUI
import Charts

struct WeatherCard: View {
    let weather: WeatherInfo
    let isNight: Bool

    @Environment(\.themePalette) private var palette
    @ScaledMetric(relativeTo: .largeTitle) private var temperatureSize = 60.0

    var body: some View {
        let latest = weather.observations.first

        VStack(alignment: .leading, spacing: 14) {
            Label("Weather Station", systemImage: "sensor")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white.opacity(0.84))

            Text(weather.stationName)
                .font(.title2.weight(.semibold))
                .accessibilityAddTraits(.isHeader)

            ViewThatFits(in: .horizontal) {
                HStack(alignment: .center, spacing: 16) {
                    conditions(latest)
                    Spacer(minLength: 0)
                    conditionSymbol(latest)
                }
                VStack(alignment: .leading, spacing: 12) {
                    conditionSymbol(latest)
                    conditions(latest)
                }
            }

            if let latest {
                let humidity = metric("Humidity", value: "\(latest.relHumidity)%", symbol: "humidity.fill")
                let wind = metric("Wind", value: "\(latest.windDir) \(latest.windSpeedKmh) km/h", symbol: "wind")
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 10) {
                        humidity
                        wind
                    }
                    VStack(spacing: 10) {
                        humidity
                        wind
                    }
                }
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .foregroundStyle(.white)
        .background {
            let blue = Color(red: 0.06, green: 0.26, blue: 0.42)
            let background = LinearGradient(
                colors: [blue.mix(with: palette.accent, by: 0.12), Color(red: 0.03, green: 0.10, blue: 0.20)],
                startPoint: .topTrailing,
                endPoint: .bottomLeading
            )
            RoundedRectangle(cornerRadius: 28).fill(background)
        }
    }

    private func conditions(_ latest: WeatherObservation?) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            if let latest {
                let airTemperature = latest.airTemp.formatted(.number.precision(.fractionLength(1)))
                Text("\(airTemperature)°C")
                    .font(.system(size: temperatureSize, weight: .light, design: .rounded))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.65)
                    .accessibilityLabel("Air temperature \(airTemperature) degrees Celsius")
                Text(latest.cloud)
                    .font(.headline)
                Text("Feels like \(latest.apparentTemp, format: .number.precision(.fractionLength(1)))°C")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.84))
            } else {
                Text("No station readings available")
                    .font(.headline)
            }
        }
    }

    private func conditionSymbol(_ latest: WeatherObservation?) -> some View {
        Image(systemName: latest?.symbolName(isNight: isNight) ?? "cloud")
            .font(.system(size: 49, weight: .medium))
            .symbolRenderingMode(.palette)
            .foregroundStyle(.white, isNight ? Color.cyan : Color.yellow)
            .accessibilityHidden(true)
    }

    private func metric(_ title: String, value: String, symbol: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(title, systemImage: symbol)
                .font(.caption.weight(.medium))
                .foregroundStyle(.white.opacity(0.84))
            Text(value)
                .font(.subheadline.weight(.semibold))
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(.white.opacity(0.10), in: RoundedRectangle(cornerRadius: 14))
        .accessibilityElement(children: .combine)
    }
}

struct StationTrendsCard: View {
    let weather: WeatherInfo
    @Binding var showPressureGuide: Bool

    private enum TemperatureSeries: CaseIterable {
        case feelsLike
        case airTemp

        var label: String {
            switch self {
            case .feelsLike: return "Feels like"
            case .airTemp:   return "Air temp"
            }
        }

        var color: Color {
            switch self {
            case .feelsLike: return .blue
            case .airTemp:   return .orange
            }
        }

        var strokeStyle: StrokeStyle {
            StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round)
        }

        func value(for observation: WeatherObservation) -> Double {
            switch self {
            case .feelsLike: return observation.apparentTemp
            case .airTemp:   return observation.airTemp
            }
        }
    }

    private struct ChartPoint: Identifiable {
        let id: UUID
        let index: Int
        let observation: WeatherObservation
    }

    private var chartObs: [WeatherObservation] { Array(weather.observations.reversed()) }
    private var chartPoints: [ChartPoint] {
        chartObs.enumerated().map { offset, obs in ChartPoint(id: obs.id, index: offset, observation: obs) }
    }
    private var xAxisIndices: [Int] {
        let last = weather.observations.count - 1
        return last > 1 ? [0, last / 2, last] : Array(weather.observations.indices)
    }

    private func formattedAxisTime(_ raw: String) -> String {
        guard raw.count == 4,
              let hour = Int(raw.prefix(2)),
              let min  = Int(raw.suffix(2)) else { return raw }
        let h12   = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour)
        let ampm  = hour < 12 ? "am" : "pm"
        return min == 0 ? "\(h12)\(ampm)" : "\(h12):\(String(format: "%02d", min))\(ampm)"
    }
    private var temperatureDomain: ClosedRange<Double> {
        let temperatures = chartObs.flatMap { [$0.apparentTemp, $0.airTemp] }
        return paddedDomain(for: temperatures, minimumPadding: 1.2)
    }
    private var pressureDomain: ClosedRange<Double> {
        paddedDomain(for: chartObs.map(\.pressureMSL), minimumPadding: 0.6)
    }
    private var humidityDomain: ClosedRange<Double> {
        paddedDomain(for: chartObs.map { Double($0.relHumidity) }, minimumPadding: 4)
    }

    private func paddedDomain(for values: [Double], minimumPadding: Double) -> ClosedRange<Double> {
        guard let minValue = values.min(), let maxValue = values.max() else { return 0...1 }
        let padding = max((maxValue - minValue) * 0.25, minimumPadding)
        return (minValue - padding)...(maxValue + padding)
    }

    var body: some View {
        CardContainer {
            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Label("Station Trends", systemImage: "chart.xyaxis.line")
                        .font(.headline)
                        .accessibilityAddTraits(.isHeader)
                    if weather.observations.count >= 2 {
                        Text("Last 24 hours")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                if weather.observations.count >= 2 {
                    Divider()
                    observationCharts
                } else {
                    Text("There aren’t enough station readings to show trends yet.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    // MARK: - Observation charts

    private var observationCharts: some View {
        VStack(alignment: .leading, spacing: 12) {
            chartSection(title: "Temperature") { temperatureChart }

            HStack(spacing: 16) {
                HStack(spacing: 4) {
                    Capsule().fill(.blue).frame(width: 16, height: 3)
                    Text("Feels like").font(.caption).foregroundStyle(.secondary)
                }
                HStack(spacing: 4) {
                    Capsule().fill(.orange).frame(width: 16, height: 3)
                    Text("Air temp").font(.caption).foregroundStyle(.secondary)
                }
            }

            chartSection(title: "Pressure (hPa)") { pressureChart }
            chartSection(title: "Humidity (%)") { humidityChart }
            DisclosureGroup("Pressure guide", isExpanded: $showPressureGuide) {
                pressureGuidance.padding(.top, 6)
            }
            .font(.subheadline.weight(.medium))
        }
    }

    @ViewBuilder
    private func chartSection<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.caption.weight(.medium)).foregroundStyle(.secondary)
            content()
        }
    }

    private var temperatureChart: some View {
        Chart {
            ForEach(TemperatureSeries.allCases, id: \.label) { series in
                ForEach(chartPoints) { point in
                    LineMark(
                        x: .value("Observation", point.index),
                        y: .value(series.label, series.value(for: point.observation)),
                        series: .value("Series", series.label)
                    )
                    .interpolationMethod(.linear)
                    .foregroundStyle(series.color)
                    .lineStyle(series.strokeStyle)
                }
            }
        }
        .chartYScale(domain: temperatureDomain)
        .chartXAxis(.hidden)
        .chartYAxis {
            AxisMarks(position: .trailing) { value in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                AxisValueLabel {
                    if let v = value.as(Double.self) {
                        Text(String(format: "%.0f°", v)).font(.caption)
                    }
                }
            }
        }
        .frame(height: 132)
    }

    private var pressureChart: some View {
        Chart {
            ForEach(chartPoints) { point in
                LineMark(
                    x: .value("Observation", point.index),
                    y: .value("Pressure", point.observation.pressureMSL)
                )
                .interpolationMethod(.linear)
                .foregroundStyle(.green)
                .lineStyle(StrokeStyle(lineWidth: 2.2, lineCap: .round, lineJoin: .round))
            }
        }
        .chartYScale(domain: pressureDomain)
        .chartXAxis(.hidden)
        .chartYAxis {
            AxisMarks(position: .trailing) { value in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                AxisValueLabel {
                    if let v = value.as(Double.self) {
                        Text(String(format: "%.0f", v)).font(.caption)
                    }
                }
            }
        }
        .frame(height: 88)
    }

    private var humidityChart: some View {
        Chart {
            ForEach(chartPoints) { point in
                LineMark(
                    x: .value("Observation", point.index),
                    y: .value("Humidity", Double(point.observation.relHumidity))
                )
                .interpolationMethod(.linear)
                .foregroundStyle(.cyan)
                .lineStyle(StrokeStyle(lineWidth: 2.2, lineCap: .round, lineJoin: .round))
            }
        }
        .chartYScale(domain: humidityDomain)
        .chartXAxis {
            AxisMarks(values: xAxisIndices) { value in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                AxisValueLabel {
                    if let index = value.as(Int.self), chartPoints.indices.contains(index) {
                        Text(formattedAxisTime(chartPoints[index].observation.localDateTime))
                            .font(.caption)
                    }
                }
            }
        }
        .chartYAxis {
            AxisMarks(position: .trailing) { value in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                AxisValueLabel {
                    if let v = value.as(Double.self) {
                        Text(String(format: "%.0f%%", v)).font(.caption)
                    }
                }
            }
        }
        .frame(height: 92)
    }

    private var pressureGuidance: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Standard Pressure: 1013.25 hPa is considered standard atmospheric pressure at sea level.")
                .font(.caption).foregroundStyle(.secondary)
            Text("High Pressure (Anticyclone): Values above 1013 hPa generally indicate stable, dry, and sunny weather.")
                .font(.caption).foregroundStyle(.secondary)
            Text("Low Pressure (Depression): Values below 1013 hPa indicate unstable, cloudy, and stormy weather.")
                .font(.caption).foregroundStyle(.secondary)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
    }
}

#Preview("Station cards") {
    ScrollView {
        VStack(spacing: 16) {
            WeatherCard(weather: MockWeatherService.mockWeather(), isNight: false)
            StationTrendsCard(weather: MockWeatherService.mockWeather(), showPressureGuide: .constant(false))
        }
        .padding()
    }
    .screenTheme(AppTheme.weather)
}
