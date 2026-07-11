//
//  WeatherView.swift
//  papaWeather
//

import SwiftUI
import FoundationModels
import CoreLocation

struct WeatherView: View {
    @AppStorage("claudeApiKey") private var claudeApiKey: String = ""
    @AppStorage("aiProvider") private var aiProviderRaw: String = AIProvider.appleIntelligence.rawValue
    @AppStorage("radarEnabled") private var radarEnabled: Bool = false
    @AppStorage(WeeklyActivityPlannerStorage.monday) private var mondayActivity: String = ""
    @AppStorage(WeeklyActivityPlannerStorage.tuesday) private var tuesdayActivity: String = ""
    @AppStorage(WeeklyActivityPlannerStorage.wednesday) private var wednesdayActivity: String = ""
    @AppStorage(WeeklyActivityPlannerStorage.thursday) private var thursdayActivity: String = ""
    @AppStorage(WeeklyActivityPlannerStorage.friday) private var fridayActivity: String = ""
    @AppStorage(WeeklyActivityPlannerStorage.saturday) private var saturdayActivity: String = ""
    @AppStorage(WeeklyActivityPlannerStorage.sunday) private var sundayActivity: String = ""
    @Environment(\.colorScheme) private var colorScheme
    @State private var selectionStore = LocationSelectionStore.shared
    @State private var weather = MockWeatherService.mockWeather()
    @State private var forecastInfo: DailyForecastInfo?
    @State private var hourlyForecast: HourlyForecastInfo?
    @State private var astronomyInfo: AstronomicalInfo?
    @State private var warnings: [WeatherWarningInfo]?
    @State private var forecastSummary = "No forecast loaded yet."
    @State private var isLoading = false
    @State private var hasLoaded = false
    @State private var statusMessage = "Tap Fetch weather to load current conditions and 7-day forecast."
    @State private var usingFallbackData = false
    @State private var isAnalysing = false
    @State private var analysisResult: String? = nil
    @State private var showAnalysis = false
    @State private var pressureInsight: String? = nil
    @State private var pressureInsightError: String? = nil
    @State private var isAnalysingPressure = false
    @State private var humidityInsight: String? = nil
    @State private var humidityInsightError: String? = nil
    @State private var isAnalysingHumidity = false
    @State private var showSettings = false
    @State private var locality: String? = nil
    @State private var fetchTime: String? = nil

    private var appleIntelligenceAvailable: Bool {
        SystemLanguageModel.default.availability == .available
    }
    private var aiProvider: AIProvider {
        AIProvider(rawValue: aiProviderRaw) ?? .appleIntelligence
    }
    private var aiIsAvailable: Bool {
        aiProvider == .appleIntelligence || !claudeApiKey.isEmpty
    }
    private var poweredByLabel: String {
        aiProvider == .claude ? "Powered by Claude" : "Powered by Apple Intelligence"
    }
    private var palette: ThemePalette {
        AppTheme.weather.palette(for: colorScheme)
    }
    private var conditionBackground: LinearGradient? {
        WeatherBackground.gradient(for: hourlyForecast?.current, colorScheme: colorScheme)
    }
    private var stationIsNight: Bool {
        if let isNight = hourlyForecast?.current?.isNight {
            return isNight
        }

        let now = Date.now
        if let today = astronomyInfo?.days.first(where: { Calendar.current.isDate($0.date, inSameDayAs: now) }),
           let sunrise = today.sunriseDate,
           let sunset = today.sunsetDate {
            return now < sunrise || now >= sunset
        }

        let hour = Calendar.current.component(.hour, from: now)
        return hour < 6 || hour >= 18
    }
    private var weeklyActivityPlan: WeeklyActivityPlan {
        WeeklyActivityPlan(
            monday: mondayActivity,
            tuesday: tuesdayActivity,
            wednesday: wednesdayActivity,
            thursday: thursdayActivity,
            friday: fridayActivity,
            saturday: saturdayActivity,
            sunday: sundayActivity
        )
    }

    var body: some View {
        NavigationStack {
            TabView {
                stationTab
                    .tabItem {
                        Label("Station", systemImage: "thermometer.medium")
                    }

                hourlyTab
                    .tabItem {
                        Label("Hourly", systemImage: "clock")
                    }

                dailyTab
                    .tabItem {
                        Label("Daily", systemImage: "calendar")
                    }

                astroTab
                    .tabItem {
                        Label("Astro", systemImage: "sun.horizon.fill")
                    }

                warningsTab
                    .tabItem {
                        Label("Warnings", systemImage: "exclamationmark.triangle.fill")
                    }
                    .badge(warnings?.count ?? 0)

                if radarEnabled {
                    RadarMapView()
                        .tabItem {
                            Label("Radar", systemImage: "cloud.rain.fill")
                        }
                }
            }
            .navigationTitle("Weather")
            .navigationBarTitleDisplayMode(.inline)
            .task {
                guard !hasLoaded else { return }
                await performFetch()
            }
            .sheet(isPresented: $showAnalysis) { analysisSheet }
            .sheet(isPresented: $showSettings) { SettingsView() }
            .onChange(of: selectionStore.selection) { _, _ in
                fetchWeather()
            }
            .toolbar {
                ToolbarItem(placement: .principal) {
                    locationSwitcher
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showSettings = true } label: {
                        Image(systemName: "gearshape.fill")
                    }
                }
            }
        }
        .screenTheme(AppTheme.weather, backgroundOverride: conditionBackground)
        .animation(.easeInOut(duration: 0.6), value: hourlyForecast?.current?.iconDescriptor)
        .animation(.easeInOut(duration: 0.6), value: hourlyForecast?.current?.isNight)
        .animation(.easeInOut(duration: 0.6), value: hourlyForecast?.current?.temp)
    }

    // MARK: - Location Switcher

    private var isDeviceSelected: Bool {
        if case .currentDevice = selectionStore.selection { return true }
        return false
    }

    private var locationSwitcher: some View {
        Menu {
            Picker("Location", selection: $selectionStore.selection) {
                Label("My Location", systemImage: "location.fill")
                    .tag(ActiveLocation.currentDevice)
                ForEach(selectionStore.saved) { location in
                    Label(location.name, systemImage: "mappin.circle.fill")
                        .tag(ActiveLocation.saved(location))
                }
            }
            .pickerStyle(.inline)

            Divider()

            Button {
                showSettings = true
            } label: {
                Label("Add or Edit Locations…", systemImage: "plus.circle")
            }
        } label: {
            VStack(spacing: 1) {
                HStack(spacing: 4) {
                    Image(systemName: isDeviceSelected ? "location.fill" : "mappin.circle.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(palette.textSecondary)
                    Text(locality ?? "Weather")
                        .font(.transit(20, weight: .bold))
                    Image(systemName: "chevron.down")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(palette.textSecondary)
                }
                if let fetchTime {
                    Text(fetchTime)
                        .font(.transit(13, weight: .medium))
                        .foregroundStyle(palette.textSecondary)
                }
            }
        }
        .tint(palette.textPrimary)
    }

    private var stationTab: some View {
        refreshableWeatherTab(spacing: 24) {
            fetchButton
            statusBanner
            WeatherCard(
                weather: weather,
                title: "Weather Station",
                isNight: stationIsNight
            )
            weatherAnalyseCard
        }
    }

    private var hourlyTab: some View {
        refreshableWeatherTab(spacing: 16) {
            HourlyTabView(hourly: hourlyForecast)
        }
    }

    private var dailyTab: some View {
        refreshableWeatherTab(spacing: 24) {
            ForecastCard(forecast: forecastInfo, debugSummary: forecastSummary)
        }
    }

    private var astroTab: some View {
        refreshableWeatherTab(spacing: 24) {
            AstroTabView(astronomy: astronomyInfo)
        }
    }

    private var warningsTab: some View {
        refreshableWeatherTab(spacing: 16) {
            WarningsTabView(warnings: warnings)
        }
    }

    private func refreshableWeatherTab<Content: View>(
        spacing: CGFloat,
        @ViewBuilder content: @escaping () -> Content
    ) -> some View {
        GeometryReader { proxy in
            ScrollView {
                VStack(spacing: spacing) {
                    content()
                }
                .frame(maxWidth: .infinity)
                .frame(minHeight: proxy.size.height + 1, alignment: .top)
                .padding()
            }
            .scrollContentBackground(.hidden)
            .scrollBounceBehavior(.always, axes: .vertical)
            .refreshable { fetchWeather() }
        }
        .background((conditionBackground ?? palette.screenBackground).ignoresSafeArea())
    }

    private var fetchButton: some View {
        Button(action: fetchWeather) {
            HStack(spacing: 8) {
                if isLoading {
                    ProgressView().tint(Color.black.opacity(0.82)).scaleEffect(0.85)
                } else {
                    Image(systemName: "arrow.clockwise")
                }
                Text(isLoading ? "Fetching..." : "Fetch weather")
            }
        }
        .buttonStyle(TransitPrimaryButtonStyle())
        .opacity(isLoading ? 0.82 : 1)
        .disabled(isLoading)
        .animation(.easeInOut(duration: 0.2), value: isLoading)
    }

    private var statusBanner: some View {
        Label {
            Text(statusMessage)
        } icon: {
            Image(systemName: usingFallbackData ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                .foregroundStyle(usingFallbackData ? AppTheme.warning : AppTheme.success)
        }
        .font(.transit(15, weight: .medium))
        .foregroundStyle(palette.textSecondary)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 2)
    }

    // MARK: - AI Weather Analysis Card

    private var weatherAnalyseCard: some View {
        ZStack {
            palette.mutedPanelBackground
                .clipShape(RoundedRectangle(cornerRadius: 16))

            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    Image(systemName: "cloud.sun.bolt.fill")
                        .font(.title3)
                        .symbolRenderingMode(.multicolor)
                    VStack(alignment: .leading, spacing: 1) {
                        Text("AI Weather Briefing")
                            .font(.transit(18, weight: .bold))
                        Text(poweredByLabel)
                            .font(.caption)
                            .foregroundStyle(palette.textSecondary)
                    }
                }

                if aiProvider == .claude && claudeApiKey.isEmpty {
                    Label("Add your Claude API key in Settings to enable.", systemImage: "key.fill")
                        .font(.caption)
                        .foregroundStyle(palette.textSecondary)
                }

                Button(action: analyseWeather) {
                    HStack(spacing: 6) {
                        Image(systemName: "sparkles")
                        Text(hasLoaded ? "Get My Weather Briefing" : "Load forecast first")
                    }
                }
                .buttonStyle(TransitPrimaryButtonStyle())
                .opacity(!aiIsAvailable || !hasLoaded ? 0.45 : 1)
                .disabled(!aiIsAvailable || !hasLoaded)
            }
            .padding(16)
        }
    }

    private var analysisSheet: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    ZStack {
                        palette.buttonBackground
                        VStack(spacing: 8) {
                            Image(systemName: "cloud.sun.bolt.fill")
                                .font(.system(size: 44))
                                .symbolRenderingMode(.multicolor)
                            Text("Weather Briefing")
                                .font(.transit(30, weight: .heavy))
                                .foregroundStyle(palette.buttonForeground)
                            Text(Date().formatted(date: .abbreviated, time: .shortened))
                                .font(.caption)
                                .foregroundStyle(palette.buttonForeground.opacity(0.72))
                        }
                        .padding(.vertical, 28)
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                    .padding(.horizontal)
                    .padding(.top, 8)

                    VStack(alignment: .leading, spacing: 14) {
                        if isAnalysing {
                            VStack(spacing: 20) {
                                ProgressView().scaleEffect(1.5)
                                Text("Analysing your forecast…")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.top, 60)
                        } else if let result = analysisResult {
                            ForEach(weatherParsedSections(result)) { section in
                                WeatherAnalysisSectionCard(title: section.title, content: section.body)
                            }
                        }
                    }
                    .padding()
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { showAnalysis = false }
                }
            }
        }
    }

    private struct WeatherParsedSection: Identifiable {
        let id    = UUID()
        let title: String
        let body:  String
    }

    private func weatherParsedSections(_ text: String) -> [WeatherParsedSection] {
        var sections: [WeatherParsedSection] = []
        var currentTitle = ""
        var currentLines: [String] = []

        for line in text.components(separatedBy: "\n") {
            if line.hasPrefix("## ") {
                let body = currentLines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
                if !currentTitle.isEmpty || !body.isEmpty {
                    sections.append(WeatherParsedSection(title: currentTitle, body: body))
                }
                currentTitle = String(line.dropFirst(3))
                currentLines = []
            } else {
                currentLines.append(line)
            }
        }
        let lastBody = currentLines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
        if !currentTitle.isEmpty || !lastBody.isEmpty {
            sections.append(WeatherParsedSection(title: currentTitle, body: lastBody))
        }
        return sections.isEmpty ? [WeatherParsedSection(title: "", body: text)] : sections
    }

    @MainActor
    private func runPressureAnalysis(observations: [WeatherObservation]) async {
        guard !observations.isEmpty else { return }
        isAnalysingPressure = true
        defer { isAnalysingPressure = false }
        do {
            pressureInsight = try await AppleIntelligenceService.analysePressure(observations: observations)
            pressureInsightError = nil
        } catch {
            pressureInsightError = error.localizedDescription
            pressureInsight = nil
        }
    }

    @MainActor
    private func runHumidityAnalysis(observations: [WeatherObservation]) async {
        guard !observations.isEmpty else { return }
        isAnalysingHumidity = true
        defer { isAnalysingHumidity = false }
        do {
            humidityInsight = try await AppleIntelligenceService.analyseHumidity(observations: observations)
            humidityInsightError = nil
        } catch {
            humidityInsightError = error.localizedDescription
            humidityInsight = nil
        }
    }

    private func analyseWeather() {
        analysisResult = nil
        isAnalysing    = true
        showAnalysis   = true

        Task {
            do {
                let result: String
                switch aiProvider {
                case .claude:
                    result = try await ClaudeService.analyseWeather(
                        forecastSummary: forecastSummary,
                        weeklyActivityPlan: weeklyActivityPlan,
                        apiKey: claudeApiKey
                    )
                case .appleIntelligence:
                    result = try await AppleIntelligenceService.analyseWeather(
                        forecastSummary: forecastSummary,
                        weeklyActivityPlan: weeklyActivityPlan
                    )
                }
                analysisResult = result
            } catch {
                analysisResult = "Error: \(error.localizedDescription)"
            }
            isAnalysing = false
        }
    }

    @MainActor
    private func fetchWeather() {
        Task { await performFetch() }
    }

    @MainActor
    private func performFetch() async {
        guard !isLoading else { return }
        print("↻ Refreshing weather bundle...")
        isLoading = true
        defer { isLoading = false }

        pressureInsight = nil
        pressureInsightError = nil
        humidityInsight = nil
        humidityInsightError = nil

        do {
            let bundle: WeatherService.WeatherBundle
            switch selectionStore.selection {
            case .currentDevice:
                bundle = try await WeatherService.shared.fetchWeatherBundle()
            case .saved(let location):
                bundle = try await WeatherService.shared.fetchWeatherBundle(
                    coordinate: location.coordinate,
                    presetLocalityName: location.name
                )
            }
            weather = bundle.weather
            Task { await runPressureAnalysis(observations: bundle.weather.observations) }
            Task { await runHumidityAnalysis(observations: bundle.weather.observations) }

            hourlyForecast = bundle.hourlyForecast
            forecastInfo = bundle.forecast
            astronomyInfo = bundle.astronomy
            warnings = bundle.warnings

            if let forecast = bundle.forecast {
                forecastSummary = forecast.debugSummary(limit: 7)
                print("🌤️ 7-day forecast (\(forecast.locationName), \(forecast.geohash))")
                print(forecastSummary)
            } else {
                forecastSummary = "Forecast unavailable for current location."
            }

            if let name = bundle.locality { locality = name }
            let stamp = Date().formatted(date: .omitted, time: .shortened)
            fetchTime = "Updated \(stamp)"
            statusMessage = "Last updated at \(stamp)"
            usingFallbackData = false
            analysisResult = nil
            hasLoaded = true
            print("✓ Weather refresh completed at \(stamp)")
        } catch is CancellationError {
            return
        } catch {
            let stamp = Date().formatted(date: .omitted, time: .shortened)
            if !hasLoaded {
                weather = MockWeatherService.mockWeather()
                forecastInfo = nil
                astronomyInfo = nil
                warnings = nil
            }
            forecastSummary = "Forecast unavailable (\(error.localizedDescription))"
            statusMessage = "Refresh failed: \(error.localizedDescription)"
            fetchTime = "Refresh failed \(stamp)"
            usingFallbackData = true
            print("✕ Weather refresh failed: \(error.localizedDescription)")
        }
    }
}

// MARK: - Weather Analysis Section Card

struct WeatherAnalysisSectionCard: View {
    let title:   String
    let content: String

    private var style: (symbol: String, color: Color) {
        let t = title.lowercased()
        if t.contains("today")                          { return ("sun.max.fill",       .orange) }
        if t.contains("commute") || t.contains("train") { return ("tram.fill",           .blue)   }
        if t.contains("week") || t.contains("ahead")   { return ("calendar",            .indigo) }
        if t.contains("activit")                        { return ("figure.walk",         .green)  }
        if t.contains("tip")                            { return ("lightbulb.fill",      .yellow) }
        if t.contains("fire")                           { return ("flame.fill",          .red)    }
        if t.contains("rain") || t.contains("storm")   { return ("cloud.rain.fill",     .cyan)   }
        if t.contains("wind")                           { return ("wind",                .teal)   }
        return                                                   ("sparkles",            .purple)
    }

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            RoundedRectangle(cornerRadius: 3)
                .fill(style.color)
                .frame(width: 4)
                .padding(.vertical, 4)

            VStack(alignment: .leading, spacing: 8) {
                if !title.isEmpty {
                    HStack(spacing: 7) {
                        Image(systemName: style.symbol)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(style.color)
                        Text(title)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(style.color)
                    }
                }
                Text(content)
                    .font(.subheadline)
                    .foregroundStyle(.primary)
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.leading, 14)
            .padding(.vertical, 14)
            .padding(.trailing, 14)
        }
        .background(style.color.opacity(0.07))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}
