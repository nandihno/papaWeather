//
//  PressureInsightCard.swift
//  papaWeather
//

import SwiftUI

struct PressureInsightCard: View {
    let isLoading: Bool
    let insight: String?
    let errorMessage: String?

    var body: some View {
        CardContainer {
            VStack(alignment: .leading, spacing: 10) {
                Label {
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Pressure Outlook")
                            .font(.transit(17, weight: .semibold))
                        Text("On-device · Apple Intelligence")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } icon: {
                    Image(systemName: "barometer")
                        .font(.title3)
                        .foregroundStyle(.green)
                }

                Divider()

                if isLoading {
                    HStack(spacing: 10) {
                        ProgressView().scaleEffect(0.85)
                        Text("Analysing pressure trend…")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                } else if let insight {
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: "sparkles")
                            .font(.caption)
                            .foregroundStyle(.green)
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
                    Text("Pressure insight will appear after weather loads.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}
