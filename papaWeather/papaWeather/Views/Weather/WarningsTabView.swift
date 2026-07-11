//
//  WarningsTabView.swift
//  papaWeather
//

import SwiftUI

struct WarningsTabView: View {
    let warnings: [WeatherWarningInfo]?
    @State private var selectedWarning: WeatherWarningInfo?

    var body: some View {
        Group {
            if let warnings, !warnings.isEmpty {
                VStack(spacing: 16) {
                    ForEach(warnings) { warning in
                        WarningCard(warning: warning)
                            // Keep the card at its ideal height — the accent bar
                            // would otherwise absorb the tab's minimum-height slack.
                            .fixedSize(horizontal: false, vertical: true)
                            .contentShape(Rectangle())
                            .onTapGesture { selectedWarning = warning }
                    }
                }
            } else if warnings != nil {
                allClearState
            } else {
                notLoadedState
            }
        }
        .sheet(item: $selectedWarning) { warning in
            WarningDetailSheet(warning: warning)
        }
    }

    private var allClearState: some View {
        VStack(spacing: 12) {
            Image(systemName: "checkmark.shield.fill")
                .font(.system(size: 40))
                .foregroundStyle(AppTheme.success)
            Text("No warnings for your area")
                .font(.subheadline.weight(.semibold))
            Text("The Bureau of Meteorology has no current warnings covering this location.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 60)
        .padding(.horizontal, 24)
    }

    private var notLoadedState: some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 40))
                .foregroundStyle(.secondary)
            Text("Warnings unavailable")
                .font(.subheadline.weight(.semibold))
            Text("Couldn't check for current warnings. Pull down to refresh.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 60)
        .padding(.horizontal, 24)
    }
}

// MARK: - Warning list card

private struct WarningCard: View {
    let warning: WeatherWarningInfo
    @Environment(\.themePalette) private var palette

    private var accent: Color {
        warning.isSevere ? .red : AppTheme.warning
    }

    var body: some View {
        CardContainer {
            HStack(alignment: .top, spacing: 0) {
                RoundedRectangle(cornerRadius: 3)
                    .fill(accent)
                    .frame(width: 4)
                    .padding(.vertical, 2)

                VStack(alignment: .leading, spacing: 10) {
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: warning.symbolName)
                            .font(.title3)
                            .foregroundStyle(accent)
                            .frame(width: 28)

                        VStack(alignment: .leading, spacing: 3) {
                            Text(warning.title)
                                .font(.transit(17, weight: .bold))
                                .fixedSize(horizontal: false, vertical: true)
                            if !warning.subtitle.isEmpty {
                                Text(warning.subtitle)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }

                        Spacer(minLength: 0)

                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.tertiary)
                            .padding(.top, 4)
                    }

                    if let issueType = warning.issueType {
                        Text(issueType.uppercased())
                            .font(.system(size: 10, weight: .heavy, design: .rounded))
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(accent.opacity(0.16))
                            .foregroundStyle(accent)
                            .clipShape(Capsule())
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        if let issuedAt = warning.issuedAt {
                            Label(
                                "Issued \(issuedAt.formatted(date: .abbreviated, time: .shortened))",
                                systemImage: "clock"
                            )
                        }
                        if let expiresAt = warning.expiresAt {
                            Label(
                                "Check again by \(expiresAt.formatted(date: .abbreviated, time: .shortened))",
                                systemImage: "clock.arrow.circlepath"
                            )
                        }
                    }
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                }
                .padding(.leading, 12)
            }
        }
    }
}

// MARK: - Warning detail sheet

private struct WarningDetailSheet: View {
    let warning: WeatherWarningInfo
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @State private var detail: WeatherWarningDetail?
    @State private var loadError: String?

    private var palette: ThemePalette {
        AppTheme.weather.palette(for: colorScheme)
    }
    private var accent: Color {
        warning.isSevere ? .red : AppTheme.warning
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    header

                    VStack(alignment: .leading, spacing: 14) {
                        if let detail {
                            detailSections(detail)
                        } else if let loadError {
                            errorSection(loadError)
                        } else {
                            VStack(spacing: 20) {
                                ProgressView().scaleEffect(1.5)
                                Text("Loading warning details…")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.top, 60)
                        }
                    }
                    .padding()
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .task { await loadDetail() }
        }
    }

    private var header: some View {
        ZStack {
            accent.opacity(0.9)
            VStack(spacing: 8) {
                Image(systemName: warning.symbolName)
                    .font(.system(size: 44))
                    .foregroundStyle(.white)
                Text(warning.title)
                    .font(.transit(24, weight: .heavy))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                if !warning.subtitle.isEmpty {
                    Text(warning.subtitle)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.85))
                        .multilineTextAlignment(.center)
                }
            }
            .padding(.vertical, 28)
            .padding(.horizontal, 16)
        }
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .padding(.horizontal)
        .padding(.top, 8)
    }

    @ViewBuilder
    private func detailSections(_ detail: WeatherWarningDetail) -> some View {
        timingSection(detail)

        if let headline = detail.headline {
            WarningSection(title: "Headline", symbol: "megaphone.fill", color: accent) {
                Text(headline)
            }
        }

        if let summary = detail.summary {
            WarningSection(title: "Summary", symbol: "text.justify.left", color: .blue) {
                Text(summary)
            }
        }

        if let situation = detail.situation {
            WarningSection(title: "Weather Situation", symbol: "cloud.sun.fill", color: .cyan) {
                Text(situation)
            }
        }

        if !detail.adviceLines.isEmpty {
            WarningSection(title: "Advice", symbol: "checklist", color: .green) {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(Array(detail.adviceLines.enumerated()), id: \.offset) { _, line in
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "circle.fill")
                                .font(.system(size: 5))
                                .foregroundStyle(.green)
                                .padding(.top, 7)
                            Text(line)
                        }
                    }
                }
            }
        }

        if let area = detail.areaSummary {
            WarningSection(title: "Areas Affected", symbol: "map.fill", color: .indigo) {
                Text(area)
            }
        }

        if let nextIssue = detail.nextIssue {
            WarningSection(title: "Next Issue", symbol: "clock.badge.exclamationmark", color: .orange) {
                Text(nextIssue)
            }
        }
    }

    private func timingSection(_ detail: WeatherWarningDetail) -> some View {
        WarningSection(title: "Timing", symbol: "clock.fill", color: accent) {
            VStack(alignment: .leading, spacing: 6) {
                if let issuedAt = detail.issuedAt ?? warning.issuedAt {
                    labeledTime("Issued", issuedAt)
                }
                if let expiresAt = detail.expiresAt ?? warning.expiresAt {
                    labeledTime("Expires", expiresAt)
                }
            }
        }
    }

    private func labeledTime(_ label: String, _ date: Date) -> some View {
        HStack(spacing: 6) {
            Text(label)
                .foregroundStyle(.secondary)
            Text(date.formatted(date: .complete, time: .shortened))
                .fontWeight(.medium)
        }
        .font(.subheadline)
    }

    private func errorSection(_ message: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "wifi.exclamationmark")
                .font(.system(size: 36))
                .foregroundStyle(.secondary)
            Text("Couldn't load warning details")
                .font(.subheadline.weight(.semibold))
            Text(message)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("Retry") {
                loadError = nil
                Task { await loadDetail() }
            }
            .buttonStyle(.bordered)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 40)
    }

    private func loadDetail() async {
        guard detail == nil else { return }
        do {
            detail = try await WeatherService.shared.fetchWarningDetail(id: warning.id)
        } catch is CancellationError {
            return
        } catch {
            loadError = error.localizedDescription
        }
    }
}

// MARK: - Detail section card

private struct WarningSection<Content: View>: View {
    let title: String
    let symbol: String
    let color: Color
    @ViewBuilder let content: Content

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            RoundedRectangle(cornerRadius: 3)
                .fill(color)
                .frame(width: 4)
                .padding(.vertical, 4)

            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 7) {
                    Image(systemName: symbol)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(color)
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(color)
                }
                content
                    .font(.subheadline)
                    .foregroundStyle(.primary)
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.leading, 14)
            .padding(.vertical, 14)
            .padding(.trailing, 14)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(color.opacity(0.07))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}
