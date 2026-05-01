//
//  AstroTabView.swift
//  papaWeather
//

import SwiftUI

struct AstroTabView: View {
    let astronomy: AstronomicalInfo?
    @State private var expandedDayId: String?

    var body: some View {
        if let astronomy {
            CardContainer {
                VStack(alignment: .leading, spacing: 12) {
                    Label("This Week", systemImage: "sun.horizon.fill")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)

                    Text(astronomy.timeZoneDescription)
                        .font(.subheadline.weight(.medium))

                    Divider()

                    HourTickScale()
                        .padding(.leading, 46)
                        .padding(.trailing, 4)

                    VStack(spacing: 0) {
                        ForEach(Array(astronomy.days.enumerated()), id: \.element.id) { index, day in
                            DayRow(
                                day: day,
                                isToday: Calendar.current.isDateInToday(day.date),
                                isExpanded: expandedDayId == day.id,
                                showDivider: index < astronomy.days.count - 1
                            )
                            .contentShape(Rectangle())
                            .onTapGesture {
                                withAnimation(.spring(duration: 0.25)) {
                                    expandedDayId = expandedDayId == day.id ? nil : day.id
                                }
                            }
                        }
                    }
                }
            }
        } else {
            emptyState
        }
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

// MARK: - Hour ticks (00, 03, 06 … 24)

private struct HourTickScale: View {
    private let hours: [Int] = [0, 3, 6, 9, 12, 15, 18, 21, 24]

    var body: some View {
        GeometryReader { geo in
            ForEach(hours, id: \.self) { h in
                Text(h == 24 ? "24" : String(format: "%02d", h))
                    .font(.system(size: 8.5, weight: .medium, design: .monospaced))
                    .foregroundStyle(.tertiary)
                    .position(
                        x: geo.size.width * CGFloat(h) / 24.0,
                        y: 6
                    )
            }
        }
        .frame(height: 12)
    }
}

// MARK: - Single day row (label + gradient bar + rise/set/duration)

private struct DayRow: View {
    let day: AstronomicalDay
    let isToday: Bool
    let isExpanded: Bool
    let showDivider: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .center, spacing: 10) {
                Text(isToday ? "Today" : shortDay)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(isToday ? Color.orange : .primary)
                    .frame(width: 46, alignment: .leading)

                DayBar(
                    riseFraction: dayFraction(day.sunriseDate),
                    setFraction: dayFraction(day.sunsetDate),
                    nowFraction: isToday ? nowFraction() : nil
                )
                .frame(height: 18)
            }

            HStack {
                Label(riseLabel, systemImage: "sunrise.fill")
                    .foregroundStyle(.orange)
                Spacer()
                Text(durationLabel)
                    .foregroundStyle(.secondary)
                Spacer()
                Label(setLabel, systemImage: "sunset.fill")
                    .foregroundStyle(.indigo)
            }
            .font(.caption.weight(.medium))
            .padding(.leading, 56)

            if isExpanded {
                AstroDayDetail(day: day, isToday: isToday)
                    .padding(.leading, 56)
                    .padding(.top, 4)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }

            if showDivider {
                Divider().padding(.top, 6)
            }
        }
        .padding(.vertical, 6)
    }

    private var shortDay: String {
        let f = DateFormatter()
        f.dateFormat = "EEE"
        return f.string(from: day.date)
    }

    private var riseLabel: String {
        day.sunriseDate.map(Self.timeText) ?? "—"
    }

    private var setLabel: String {
        day.sunsetDate.map(Self.timeText) ?? "—"
    }

    private var durationLabel: String {
        guard let m = day.daylightMinutes else { return "" }
        return "\(m / 60)h \(String(format: "%02d", m % 60))m of light"
    }

    private func dayFraction(_ date: Date?) -> CGFloat? {
        guard let date else { return nil }
        let cal = Calendar.current
        let start = cal.startOfDay(for: day.date)
        let secs = date.timeIntervalSince(start)
        return CGFloat(max(0, min(1, secs / 86_400)))
    }

    private func nowFraction() -> CGFloat? {
        let now = Date()
        let cal = Calendar.current
        let start = cal.startOfDay(for: day.date)
        let secs = now.timeIntervalSince(start)
        guard secs >= 0, secs <= 86_400 else { return nil }
        return CGFloat(secs / 86_400)
    }

    static func timeText(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "h:mma"
        f.amSymbol = "am"
        f.pmSymbol = "pm"
        return f.string(from: date)
    }
}

// MARK: - Gradient day-bar with rise/set tick marks and now marker

private struct DayBar: View {
    let riseFraction: CGFloat?
    let setFraction: CGFloat?
    let nowFraction: CGFloat?

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height

            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(skyGradient)
                    .overlay(
                        RoundedRectangle(cornerRadius: 5, style: .continuous)
                            .strokeBorder(Color.primary.opacity(0.18), lineWidth: 0.7)
                    )

                if let rf = riseFraction {
                    tick(at: rf * w, height: h)
                }
                if let sf = setFraction {
                    tick(at: sf * w, height: h)
                }
                if let nf = nowFraction {
                    nowMarker(at: nf * w, height: h)
                }
            }
        }
    }

    private func tick(at x: CGFloat, height h: CGFloat) -> some View {
        Rectangle()
            .fill(Color.primary.opacity(0.65))
            .frame(width: 1.2, height: h + 6)
            .offset(x: x - 0.6, y: -3)
    }

    private func nowMarker(at x: CGFloat, height h: CGFloat) -> some View {
        ZStack {
            Rectangle()
                .fill(Color.orange)
                .frame(width: 1.6, height: h + 8)
            Circle()
                .fill(Color.orange)
                .overlay(Circle().strokeBorder(Color.white.opacity(0.85), lineWidth: 1))
                .frame(width: 9, height: 9)
                .offset(y: -(h / 2) - 1)
        }
        .offset(x: x - 0.8, y: -4)
    }

    // Sunrise sweep: night → purple → orange → gold → sky.
    // Sunset sweep mirrors. Stops are positioned around rise/set fractions.
    private var skyGradient: LinearGradient {
        let r = riseFraction ?? 0.27
        let s = setFraction ?? 0.79
        let w: CGFloat = 45.0 / 1440.0   // half-sweep width as fraction of day

        let stops: [Gradient.Stop] = [
            .init(color: night,   location: 0),
            .init(color: night,   location: max(0, r - w)),
            .init(color: purple,  location: max(0, r - w * 0.55)),
            .init(color: orange,  location: r),
            .init(color: gold,    location: min(1, r + w * 0.5)),
            .init(color: sky,     location: min(1, r + w)),
            .init(color: midDay,  location: (r + s) / 2),
            .init(color: sky,     location: max(0, s - w)),
            .init(color: gold,    location: max(0, s - w * 0.5)),
            .init(color: orange,  location: s),
            .init(color: purple,  location: min(1, s + w * 0.55)),
            .init(color: night,   location: min(1, s + w)),
            .init(color: night,   location: 1),
        ]

        return LinearGradient(
            stops: stops.sorted { $0.location < $1.location },
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    private let night  = Color(red: 0.043, green: 0.082, blue: 0.188)
    private let purple = Color(red: 0.227, green: 0.141, blue: 0.322)
    private let orange = Color(red: 0.910, green: 0.478, blue: 0.227)
    private let gold   = Color(red: 0.965, green: 0.827, blue: 0.420)
    private let sky    = Color(red: 0.620, green: 0.788, blue: 0.933)
    private let midDay = Color(red: 0.784, green: 0.886, blue: 0.957)
}

// MARK: - Expanded detail panel (matches the wireframe's expand state)

private struct AstroDayDetail: View {
    let day: AstronomicalDay
    let isToday: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(longDate)
                .font(.subheadline.weight(.semibold))

            HStack(spacing: 8) {
                if let rise = day.sunriseDate {
                    statPill(icon: "sunrise.fill", color: .orange, label: "Sunrise", value: DayRow.timeText(rise))
                }
                if let set = day.sunsetDate {
                    statPill(icon: "sunset.fill", color: .indigo, label: "Sunset", value: DayRow.timeText(set))
                }
            }

            if let m = day.daylightMinutes {
                statPill(
                    icon: "sun.max.fill",
                    color: .yellow,
                    label: "Daylight",
                    value: "\(m / 60)h \(String(format: "%02d", m % 60))m"
                )
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.secondary.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private var longDate: String {
        let f = DateFormatter()
        f.dateFormat = "EEEE d MMM"
        return f.string(from: day.date)
    }

    private func statPill(icon: String, color: Color, label: String, value: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundStyle(color)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.caption.weight(.semibold))
        }
    }
}
