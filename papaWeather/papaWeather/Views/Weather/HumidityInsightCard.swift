//
//  HumidityInsightCard.swift
//  papaWeather
//

import SwiftUI

struct HumidityInsightCard: View {
    let isLoading: Bool
    let insight: String?
    let errorMessage: String?

    var body: some View {
        CardContainer {
            VStack(alignment: .leading, spacing: 10) {
                Label {
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Humidity Health Gauge")
                            .font(.transit(15, weight: .semibold))
                        Text("On-device · Apple Intelligence")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                } icon: {
                    Image(systemName: "humidity.fill")
                        .font(.title3)
                        .foregroundStyle(.cyan)
                }

                Divider()

                if isLoading {
                    HStack(spacing: 10) {
                        ProgressView().scaleEffect(0.85)
                        Text("Analysing humidity data…")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                } else if let insight {
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: "sparkles")
                            .font(.caption)
                            .foregroundStyle(.cyan)
                            .padding(.top, 2)
                        Text(insight)
                            .font(.subheadline)
                            .lineSpacing(3)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                } else if let errorMessage {
                    Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text("Humidity insight will appear after weather loads.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}
