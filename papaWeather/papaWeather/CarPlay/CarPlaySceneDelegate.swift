//
//  CarPlaySceneDelegate.swift
//  papaWeather
//

import CarPlay
import UIKit

/// Presents a deliberately small Driving Task experience: current conditions and
/// the next six hours. Phone-only features such as radar, settings, and AI analysis
/// are intentionally excluded.
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

    private func makeCurrentWeatherTemplate(_ summary: DrivingWeatherSummary) -> CPInformationTemplate {
        let current = summary.current
        let condition = "\(current.cloud), \(wholeDegrees(current.airTemp))°C (feels \(wholeDegrees(current.apparentTemp))°C)"
        let updated = summary.fetchedAt.formatted(date: .omitted, time: .shortened)

        var actions: [CPTextButton] = []
        if !summary.upcomingHours.isEmpty {
            actions.append(
                CPTextButton(title: "Next 6 Hours", textStyle: .normal) { [weak self] _ in
                    self?.showHourlyForecast()
                }
            )
        }
        actions.append(
            CPTextButton(title: "Refresh", textStyle: .normal) { [weak self] _ in
                self?.refreshWeather(forceRefresh: true)
            }
        )

        return CPInformationTemplate(
            title: summary.locality,
            layout: .leading,
            items: [
                CPInformationItem(title: "Now", detail: condition),
                CPInformationItem(title: "Rain", detail: summary.rainOutlook),
                CPInformationItem(title: "Wind", detail: summary.windOutlook),
                CPInformationItem(title: "Driving outlook", detail: summary.drivingOutlook),
                CPInformationItem(title: "Updated", detail: "\(updated) · \(summary.stationName)")
            ],
            actions: actions
        )
    }

    private func showHourlyForecast() {
        guard let summary = latestSummary, !summary.upcomingHours.isEmpty else { return }

        let rows = summary.upcomingHours.map { hour in
            let gustDetail = hour.gustSpeedKmh > 0 ? " · Gusts \(hour.gustSpeedKmh) km/h" : ""
            let item = CPListItem(
                text: "\(hour.time)  ·  \(hour.temp)°C",
                detailText: "Rain \(hour.rainChance)% · Wind \(hour.windDirection) \(hour.windSpeedKmh) km/h\(gustDetail)",
                image: UIImage(systemName: hour.symbolName)
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
            image: UIImage(systemName: symbol)
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
}
