//
//  HourlyForecastCard.swift
//  papaWeather
//

import SwiftUI

struct HourlyForecastCard: View {
    let hourly: HourlyForecastInfo?

    var body: some View {
        if let hourly, !hourly.hours.isEmpty {
            CardContainer {
                VStack(alignment: .leading, spacing: 12) {
                    Label("Next \(hourly.hours.count) Hours", systemImage: "clock.fill")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 14) {
                            ForEach(hourly.hours) { hour in
                                VStack(spacing: 8) {
                                    Text(hour.time)
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(.secondary)

                                    Image(systemName: hour.symbolName)
                                        .font(.title3)
                                        .foregroundStyle(hourlySymbolColor(for: hour))
                                        .frame(height: 24)

                                    Text("\(hour.temp)°")
                                        .font(.title3.weight(.medium))

                                    Text("Feels \(hour.feelsLike)°")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)

                                    HStack(spacing: 2) {
                                        Image(systemName: "drop.fill").font(.system(size: 8))
                                        Text("\(hour.rainChance)%").font(.caption.weight(.medium))
                                    }
                                    .foregroundStyle(hour.rainChance > 30 ? .blue : .secondary)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 3)
                                    .background(
                                        Capsule().fill(hour.rainChance > 30
                                                       ? Color.blue.opacity(0.12)
                                                       : Color.secondary.opacity(0.08))
                                    )
                                }
                                .frame(minWidth: 58)
                            }
                        }
                        .padding(.horizontal, 2)
                    }
                }
            }
        }
    }

    private func hourlySymbolColor(for hour: HourlyForecastHour) -> Color {
        let desc = hour.iconDescriptor.lowercased()
        if desc.contains("storm")                              { return .purple }
        if desc.contains("rain") || desc.contains("shower")   { return .blue }
        if desc.contains("cloudy")                             { return .gray }
        if hour.isNight                                        { return .indigo }
        return .orange
    }
}
