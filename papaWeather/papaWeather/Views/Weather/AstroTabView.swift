//
//  AstroTabView.swift
//  papaWeather
//

import SwiftUI
import Charts

struct AstroTabView: View {
    let astronomy: AstronomicalInfo?
    @State private var selectedDayId: String?

    var body: some View {
        if let astronomy {
            CardContainer {
                VStack(alignment: .leading, spacing: 12) {
                    Label("10-Day Astro", systemImage: "sun.horizon.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)

                    Text(astronomy.timeZoneDescription)
                        .font(.subheadline.weight(.medium))

                    Divider()

                    daylightChart(days: astronomy.days)

                    if let id = selectedDayId, let day = astronomy.days.first(where: { $0.id == id }) {
                        Divider()
                        AstroSelectedDayDetail(day: day)
                            .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                }
            }
        } else {
            emptyState
        }
    }

    private func daylightChart(days: [AstronomicalDay]) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 12) {
                Label("Sunrise", systemImage: "sunrise.fill")
                    .foregroundStyle(.orange)
                Label("Sunset", systemImage: "sunset.fill")
                    .foregroundStyle(.indigo)
            }
            .font(.caption2.weight(.semibold))
            .foregroundStyle(.tertiary)

            Chart {
                ForEach(days) { day in
                    if let rise = day.sunriseDate, let set = day.sunsetDate {
                        BarMark(
                            x: .value("Day", shortDayLabel(day.date)),
                            yStart: .value("Sunrise", hoursFromMidnight(rise)),
                            yEnd: .value("Sunset", hoursFromMidnight(set))
                        )
                        .foregroundStyle(
                            selectedDayId == nil || selectedDayId == day.id
                            ? LinearGradient(
                                colors: [.orange.opacity(0.7), .yellow.opacity(0.5), .indigo.opacity(0.6)],
                                startPoint: .bottom, endPoint: .top
                              )
                            : LinearGradient(
                                colors: [.secondary.opacity(0.2), .secondary.opacity(0.2)],
                                startPoint: .bottom, endPoint: .top
                              )
                        )
                        .cornerRadius(4)

                        PointMark(
                            x: .value("Day", shortDayLabel(day.date)),
                            y: .value("Sunrise", hoursFromMidnight(rise))
                        )
                        .foregroundStyle(selectedDayId == nil || selectedDayId == day.id ? .orange : .secondary.opacity(0.3))
                        .symbolSize(30)

                        PointMark(
                            x: .value("Day", shortDayLabel(day.date)),
                            y: .value("Sunset", hoursFromMidnight(set))
                        )
                        .foregroundStyle(selectedDayId == nil || selectedDayId == day.id ? .indigo : .secondary.opacity(0.3))
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
                            Text(hourLabel(v)).font(.caption2)
                        }
                    }
                }
            }
            .chartXAxis {
                AxisMarks { _ in AxisValueLabel().font(.caption2) }
            }
            .frame(height: 120)
            .chartOverlay { proxy in
                GeometryReader { geo in
                    Rectangle()
                        .fill(.clear)
                        .contentShape(Rectangle())
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onEnded { value in
                                    let x = value.location.x - geo[proxy.plotFrame!].origin.x
                                    if let label: String = proxy.value(atX: x) {
                                        withAnimation(.spring(duration: 0.25)) {
                                            if let match = days.first(where: { shortDayLabel($0.date) == label }) {
                                                selectedDayId = selectedDayId == match.id ? nil : match.id
                                            }
                                        }
                                    }
                                }
                        )
                }
            }
        }
    }

    private func hoursFromMidnight(_ date: Date) -> Double {
        let c = Calendar.current.dateComponents([.hour, .minute], from: date)
        return Double(c.hour ?? 0) + Double(c.minute ?? 0) / 60.0
    }

    private func hourLabel(_ hours: Double) -> String {
        let h = Int(hours)
        if h == 0 || h == 24 { return "12 AM" }
        if h == 12 { return "12 PM" }
        return h < 12 ? "\(h) AM" : "\(h - 12) PM"
    }

    private func shortDayLabel(_ date: Date) -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = "EEE"
        return fmt.string(from: date)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "sun.horizon")
                .font(.system(size: 40))
                .foregroundStyle(.secondary)
            Text("No astro data available")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 60)
    }
}

private struct AstroSelectedDayDetail: View {
    let day: AstronomicalDay

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(dayLabel)
                    .font(.subheadline.weight(.semibold))
                Spacer()
                if let minutes = day.daylightMinutes {
                    Text("\(minutes / 60)h \(minutes % 60)m")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
            }

            HStack(spacing: 10) {
                if let rise = day.sunriseDate {
                    AstroStatPill(label: "Sunrise", value: timeText(rise), symbol: "sunrise.fill")
                }
                if let set = day.sunsetDate {
                    AstroStatPill(label: "Sunset", value: timeText(set), symbol: "sunset.fill")
                }
            }
        }
    }

    private var dayLabel: String {
        let fmt = DateFormatter()
        fmt.dateFormat = "EEEE d MMM"
        return fmt.string(from: day.date)
    }
}

private struct AstroStatPill: View {
    let label: String
    let value: String
    let symbol: String

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: symbol)
            Text("\(label): \(value)")
        }
        .font(.caption2)
        .foregroundStyle(.secondary)
    }
}

private func timeText(_ date: Date) -> String {
    let fmt = DateFormatter()
    fmt.dateFormat = "h:mm a"
    fmt.timeZone = .current
    return fmt.string(from: date)
}
