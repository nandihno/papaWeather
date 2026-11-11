//
//  PapaWeatherWidgetsBundle.swift
//  papaWeatherWidgets
//

import SwiftUI
import WidgetKit

@main
struct PapaWeatherWidgetsBundle: WidgetBundle {
    var body: some Widget {
        CurrentConditionsWidget()
        HourlyOverviewWidget()
    }
}
