//
//  CarPlaySceneDelegate.swift
//  papaWeather
//

import CarPlay
import UIKit

/// Presents a deliberately small Driving Task experience: current conditions and
/// the next six hours. Phone-only features such as radar, settings, and AI analysis
/// are intentionally excluded.
///
/// The layout is built for a glance from the driver's seat: every row leads with a
/// coloured icon, values are short, and driving conditions are shown as a
/// traffic-light status rather than a sentence.
final class CarPlaySceneDelegate: UIResponder, CPTemplateApplicationSceneDelegate {
    private weak var interfaceController: CPInterfaceController?
    private var refreshTask: Task<Void, Never>?
    private var latestSummary: DrivingWeatherSummary?

    func templateApplicationScene(
        _ templateApplicationScene: CPTemplateApplicationScene,
        didConnect interfaceController: CPInterfaceController
    ) {
        self.interfaceController = interfaceController
        setRootTemplate(makeLoadingTemplate(), animated: false)
        refreshWeather(forceRefresh: false)
    }

    func templateApplicationScene(
        _ templateApplicationScene: CPTemplateApplicationScene,
        didDisconnectInterfaceController interfaceController: CPInterfaceController
    ) {
        refreshTask?.cancel()
        refreshTask = nil
        latestSummary = nil
        self.interfaceController = nil
    }

    private func refreshWeather(forceRefresh: Bool) {
        refreshTask?.cancel()
        refreshTask = Task { [weak self] in
            guard let self else { return }
            do {
                let summary = try await WeatherService.shared.fetchDrivingWeather(
                    forceRefresh: forceRefresh
                )
                try Task.checkCancellation()
                latestSummary = summary
                setRootTemplate(makeCurrentWeatherTemplate(summary), animated: true)
            } catch is CancellationError {
                return
            } catch {
                setRootTemplate(makeErrorTemplate(error), animated: true)
            }
        }
    }

    private func makeLoadingTemplate() -> CPInformationTemplate {
        CPInformationTemplate(
            title: "Drive Weather",
            layout: .leading,
            items: [CPInformationItem(title: "Loading", detail: "Getting local driving conditions…")],
            actions: []
        )
    }

    // MARK: - Current weather (root)

    private func makeCurrentWeatherTemplate(_ summary: DrivingWeatherSummary) -> CPListTemplate {
        var sections: [CPListSection] = []

        // Warnings first — highest priority, colour-coded red/orange.
        if !summary.warnings.isEmpty {
            sections.append(CPListSection(items: [warningsSummaryRow(summary)]))
        }

        // Hero: big condition icon + temperature. Suburb is the template title.
        sections.append(CPListSection(items: [heroRow(summary)]))

        // Compact, colour-coded metric rows.
        sections.append(CPListSection(items: [
            rainRow(summary),
            windRow(summary),
            drivingStatusRow(summary),
            hourlyNavigationRow(summary)
        ].compactMap { $0 }))

        let template = CPListTemplate(title: summary.locality, sections: sections)

        // Refresh lives in the nav bar as an icon so it doesn't add a text row.
        let refreshImage = tintedSymbol("arrow.clockwise", color: .label, pointSize: 20)
            ?? UIImage(systemName: "arrow.clockwise") ?? UIImage()
        let refresh = CPBarButton(image: refreshImage) { [weak self] _ in
            self?.refreshWeather(forceRefresh: true)
        }
        template.trailingNavigationBarButtons = [refresh]

        return template
    }

    private func heroRow(_ summary: DrivingWeatherSummary) -> CPListItem {
        let current = summary.current
        let isNight = summary.upcomingHours.first?.isNight ?? false
        let feels = wholeDegrees(current.apparentTemp)
        let item = CPListItem(
            text: "\(wholeDegrees(current.airTemp))°  ·  \(current.cloud)",
            detailText: "Feels \(feels)°",
            image: weatherSymbol(current.symbolName(isNight: isNight), pointSize: 44)
        )
        item.handler = { _, completion in completion() }
        return item
    }

    private func rainRow(_ summary: DrivingWeatherSummary) -> CPListItem {
        let chance = summary.peakRainChance
        let color: UIColor
        switch chance {
        case 70...: color = .systemBlue
        case 40...: color = .systemTeal
        default:    color = .systemGray
        }
        let item = CPListItem(
            text: "Rain  \(chance)%",
            detailText: rainDetail(summary),
            image: tintedSymbol("drop.fill", color: color)
        )
        item.handler = { _, completion in completion() }
        return item
    }

    private func rainDetail(_ summary: DrivingWeatherSummary) -> String {
        guard let wettest = summary.upcomingHours.max(by: { $0.rainChance < $1.rainChance }),
              wettest.rainChance >= 40 else {
            return "Next 6 h"
        }
        return "Peak around \(wettest.time)"
    }

    private func windRow(_ summary: DrivingWeatherSummary) -> CPListItem {
        let peak = summary.peakWindKmh
        let color: UIColor
        switch peak {
        case 60...: color = .systemRed
        case 40...: color = .systemOrange
        default:    color = .systemGray
        }
        let direction = summary.upcomingHours.first?.windDirection ?? summary.current.windDir
        let item = CPListItem(
            text: "Wind  \(peak) km/h",
            detailText: direction,
            image: tintedSymbol("wind", color: color)
        )
        item.handler = { _, completion in completion() }
        return item
    }

    private func drivingStatusRow(_ summary: DrivingWeatherSummary) -> CPListItem {
        let symbol: String
        let color: UIColor
        switch summary.drivingCondition {
        case .clear:
            symbol = "checkmark.circle.fill"
            color = .systemGreen
        case .caution:
            symbol = "exclamationmark.triangle.fill"
            color = .systemOrange
        case .hazard:
            symbol = "exclamationmark.octagon.fill"
            color = .systemRed
        }
        let item = CPListItem(
            text: summary.drivingHeadline,
            detailText: summary.drivingOutlook,
            image: tintedSymbol(symbol, color: color)
        )
        item.handler = { _, completion in completion() }
        return item
    }

    private func hourlyNavigationRow(_ summary: DrivingWeatherSummary) -> CPListItem? {
        guard !summary.upcomingHours.isEmpty else { return nil }
        let item = CPListItem(
            text: "Next 6 hours",
            detailText: nil,
            image: tintedSymbol("clock.fill", color: .systemGray)
        )
        item.accessoryType = .disclosureIndicator
        item.handler = { [weak self] _, completion in
            self?.showHourlyForecast()
            completion()
        }
        return item
    }

    private func warningsSummaryRow(_ summary: DrivingWeatherSummary) -> CPListItem {
        let count = summary.warnings.count
        let noun = count == 1 ? "warning" : "warnings"
        let severe = summary.warnings.contains(where: \.isSevere)
        let item = CPListItem(
            text: "\(count) \(noun)",
            detailText: summary.warnings.first?.title,
            image: tintedSymbol(
                "exclamationmark.triangle.fill",
                color: severe ? .systemRed : .systemOrange
            )
        )
        item.accessoryType = .disclosureIndicator
        item.handler = { [weak self] _, completion in
            self?.showWarnings()
            completion()
        }
        return item
    }

    // MARK: - Warnings

    private func showWarnings() {
        guard let summary = latestSummary, !summary.warnings.isEmpty else { return }

        let rows = summary.warnings.map { warning in
            var details: [String] = []
            if let issueType = warning.issueType { details.append(issueType) }
            if let expiresAt = warning.expiresAt {
                details.append("Until \(expiresAt.formatted(date: .abbreviated, time: .shortened))")
            }
            let item = CPListItem(
                text: warning.title,
                detailText: details.joined(separator: " · "),
                image: tintedSymbol(warning.symbolName, color: warning.isSevere ? .systemRed : .systemOrange)
            )
            item.accessoryType = .disclosureIndicator
            item.handler = { [weak self] _, completion in
                guard let self else {
                    completion()
                    return
                }
                self.showWarningDetail(warning, selectionCompletion: completion)
            }
            return item
        }

        let template = CPListTemplate(
            title: "Warnings",
            sections: [CPListSection(items: rows)]
        )
        interfaceController?.pushTemplate(template, animated: true) { _, _ in }
    }

    private func showWarningDetail(
        _ warning: WeatherWarningInfo,
        selectionCompletion: @escaping () -> Void
    ) {
        guard let interfaceController else {
            selectionCompletion()
            return
        }

        Task { [weak self] in
            guard let self else {
                selectionCompletion()
                return
            }

            var items: [CPInformationItem] = []
            do {
                let detail = try await WeatherService.shared.fetchWarningDetail(id: warning.id)
                if let issuedAt = detail.issuedAt ?? warning.issuedAt {
                    items.append(CPInformationItem(
                        title: "Issued",
                        detail: issuedAt.formatted(date: .abbreviated, time: .shortened)
                    ))
                }
                if let expiresAt = detail.expiresAt ?? warning.expiresAt {
                    items.append(CPInformationItem(
                        title: "Expires",
                        detail: expiresAt.formatted(date: .abbreviated, time: .shortened)
                    ))
                }
                if let area = detail.areaSummary {
                    items.append(CPInformationItem(title: "Areas", detail: area))
                }
                // Keep in-car advice glanceable: first couple of points only.
                if !detail.adviceLines.isEmpty {
                    items.append(CPInformationItem(
                        title: "Advice",
                        detail: detail.adviceLines.prefix(2).joined(separator: " ")
                    ))
                }
                if let nextIssue = detail.nextIssue {
                    items.append(CPInformationItem(title: "Next issue", detail: nextIssue))
                }
            } catch {
                items = [
                    CPInformationItem(title: warning.title, detail: warning.subtitle),
                    CPInformationItem(title: "Details unavailable", detail: error.localizedDescription)
                ]
            }

            let template = CPInformationTemplate(
                title: warning.title,
                layout: .leading,
                items: items,
                actions: []
            )
            interfaceController.pushTemplate(template, animated: true) { _, _ in
                selectionCompletion()
            }
        }
    }

    // MARK: - Hourly forecast

    private func showHourlyForecast() {
        guard let summary = latestSummary, !summary.upcomingHours.isEmpty else { return }

        let rows = summary.upcomingHours.map { hour in
            let item = CPListItem(
                text: "\(hour.time)   \(hour.temp)°",
                detailText: hourlyDetail(hour),
                image: weatherSymbol(hour.symbolName)
            )
            item.accessoryType = .disclosureIndicator
            item.handler = { [weak self] _, completion in
                guard let self else {
                    completion()
                    return
                }
                self.showHourDetail(hour, selectionCompletion: completion)
            }
            return item
        }
        let template = CPListTemplate(
            title: "Next 6 Hours",
            sections: [CPListSection(items: rows)]
        )
        interfaceController?.pushTemplate(template, animated: true) { _, _ in }
    }

    private func hourlyDetail(_ hour: HourlyForecastHour) -> String {
        var parts = ["Rain \(hour.rainChance)%"]
        if hour.gustSpeedKmh > 0 {
            parts.append("Gusts \(hour.gustSpeedKmh) km/h")
        } else {
            parts.append("Wind \(hour.windSpeedKmh) km/h")
        }
        return parts.joined(separator: " · ")
    }

    private func showHourDetail(
        _ hour: HourlyForecastHour,
        selectionCompletion: @escaping () -> Void
    ) {
        guard let interfaceController else {
            selectionCompletion()
            return
        }

        var items = [
            makeDetailItem(
                title: conditionLabel(for: hour),
                detail: hour.isNight ? "Night conditions" : "Daylight conditions",
                symbol: hour.symbolName
            ),
            makeDetailItem(
                title: "Temperature",
                detail: "\(hour.temp)°C · Feels like \(hour.feelsLike)°C",
                symbol: "thermometer.medium"
            ),
            makeDetailItem(
                title: "Rain chance",
                detail: "\(hour.rainChance)%",
                symbol: "drop.fill"
            ),
            makeDetailItem(
                title: "Wind",
                detail: "\(hour.windDirection) \(hour.windSpeedKmh) km/h",
                symbol: "wind"
            ),
            makeDetailItem(
                title: "Humidity",
                detail: "\(hour.relativeHumidity)%",
                symbol: "humidity.fill"
            )
        ]

        if hour.gustSpeedKmh > 0 {
            items.insert(
                makeDetailItem(
                    title: "Wind gusts",
                    detail: "Up to \(hour.gustSpeedKmh) km/h",
                    symbol: "wind.circle.fill"
                ),
                at: 4
            )
        }

        let template = CPListTemplate(
            title: hour.time,
            sections: [CPListSection(items: items)]
        )
        interfaceController.pushTemplate(template, animated: true) { _, _ in
            selectionCompletion()
        }
    }

    private func makeDetailItem(title: String, detail: String, symbol: String) -> CPListItem {
        let item = CPListItem(
            text: title,
            detailText: detail,
            image: weatherSymbol(symbol)
        )
        // Detail rows are informational. Completing immediately prevents CarPlay
        // from leaving a selection spinner on a row that has no deeper action.
        item.handler = { _, completion in completion() }
        return item
    }

    private func conditionLabel(for hour: HourlyForecastHour) -> String {
        hour.iconDescriptor
            .replacingOccurrences(of: "_", with: " ")
            .capitalized
    }

    private func makeErrorTemplate(_ error: Error) -> CPInformationTemplate {
        let retry = CPTextButton(title: "Retry", textStyle: .normal) { [weak self] _ in
            self?.refreshWeather(forceRefresh: true)
        }
        return CPInformationTemplate(
            title: "Weather Unavailable",
            layout: .leading,
            items: [
                CPInformationItem(title: "Unable to update", detail: error.localizedDescription),
                CPInformationItem(
                    title: "Location access",
                    detail: "Open papaWeather on iPhone to check location permission, then retry."
                )
            ],
            actions: [retry]
        )
    }

    private func setRootTemplate(_ template: CPTemplate, animated: Bool) {
        interfaceController?.setRootTemplate(template, animated: animated) { _, _ in }
    }

    private func wholeDegrees(_ value: Double) -> Int {
        Int(value.rounded())
    }

    // MARK: - Icon rendering

    /// Renders a weather SF Symbol in its natural multicolour form (yellow sun,
    /// grey cloud, blue rain) so conditions read at a glance without labels.
    private func weatherSymbol(_ name: String, pointSize: CGFloat = 34) -> UIImage? {
        let config = UIImage.SymbolConfiguration(pointSize: pointSize, weight: .semibold)
            .applying(UIImage.SymbolConfiguration.preferringMulticolor())
        return flattened(UIImage(systemName: name, withConfiguration: config))
    }

    /// Renders an SF Symbol in a single deliberate colour (used for status and
    /// metric rows where the colour itself carries meaning).
    private func tintedSymbol(_ name: String, color: UIColor, pointSize: CGFloat = 30) -> UIImage? {
        let config = UIImage.SymbolConfiguration(pointSize: pointSize, weight: .semibold)
            .applying(UIImage.SymbolConfiguration(hierarchicalColor: color))
        return flattened(UIImage(systemName: name, withConfiguration: config))
    }

    /// CarPlay treats a symbol image as a *template* and re-tints it monochrome,
    /// discarding our colours. Drawing the already-coloured symbol into a bitmap
    /// produces flat coloured pixels that CarPlay renders as-is.
    private func flattened(_ image: UIImage?) -> UIImage? {
        guard let image else { return nil }
        let format = UIGraphicsImageRendererFormat.default()
        format.opaque = false
        format.scale = 3
        let renderer = UIGraphicsImageRenderer(size: image.size, format: format)
        let raster = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: image.size))
        }
        return raster.withRenderingMode(.alwaysOriginal)
    }
}
