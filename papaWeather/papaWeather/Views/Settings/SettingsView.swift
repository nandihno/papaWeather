//
//  SettingsView.swift
//  papaWeather
//

import SwiftUI

struct SettingsView: View {
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
    @Environment(\.dismiss) private var dismiss

    private var useClaude: Binding<Bool> {
        Binding(
            get: { aiProviderRaw == AIProvider.claude.rawValue },
            set: { aiProviderRaw = ($0 ? AIProvider.claude : AIProvider.appleIntelligence).rawValue }
        )
    }

    var body: some View {
        NavigationStack {
            Form {
                aiSection
                weeklyPlannerSection
                weatherStationsSection
                radarSection
                aboutSection
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    // MARK: - AI Analysis

    @ViewBuilder
    private var aiSection: some View {
        Section {
            Toggle("Use Claude AI", isOn: useClaude)

            if useClaude.wrappedValue {
                LabeledContent("API Key") {
                    SecureField("sk-ant-...", text: $claudeApiKey)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .multilineTextAlignment(.trailing)
                }
            }
        } header: {
            Text("AI Analysis")
        } footer: {
            if useClaude.wrappedValue {
                if claudeApiKey.isEmpty {
                    Text("Enter your Claude API key to enable AI weather briefings. Get one at console.anthropic.com.")
                        .foregroundStyle(.orange)
                } else {
                    Text("Using Claude AI for weather analysis.")
                }
            } else {
                Text("Using Apple Intelligence (on-device) for weather briefings. Toggle on to use Claude AI instead.")
            }
        }
    }

    // MARK: - Weekly Planner

    @ViewBuilder
    private var weeklyPlannerSection: some View {
        Section {
            ForEach(WeeklyActivityDay.allCases) { day in
                WeeklyPlannerDayRow(
                    day: day,
                    activity: cappedBinding(for: day),
                    characterLimit: WeeklyActivityPlan.maxActivityLength
                )
            }
        } header: {
            Text("Weekly Planner")
        } footer: {
            Text("Add weather-sensitive plans for each day. Weather briefings use these entries to tailor activity advice instead of assuming fixed weekly routines.")
        }
    }

    private func cappedBinding(for day: WeeklyActivityDay) -> Binding<String> {
        let source = binding(for: day)
        return Binding(
            get: {
                String(source.wrappedValue.prefix(WeeklyActivityPlan.maxActivityLength))
            },
            set: {
                source.wrappedValue = String($0.prefix(WeeklyActivityPlan.maxActivityLength))
            }
        )
    }

    private func binding(for day: WeeklyActivityDay) -> Binding<String> {
        switch day {
        case .monday:
            $mondayActivity
        case .tuesday:
            $tuesdayActivity
        case .wednesday:
            $wednesdayActivity
        case .thursday:
            $thursdayActivity
        case .friday:
            $fridayActivity
        case .saturday:
            $saturdayActivity
        case .sunday:
            $sundayActivity
        }
    }

    // MARK: - Weather Stations

    @ViewBuilder
    private var weatherStationsSection: some View {
        Section {
            NavigationLink {
                WeatherStationsView()
            } label: {
                LabeledContent("BOM Stations") {
                    Text("\(WeatherStation.defaults.count) built-in")
                        .foregroundStyle(.secondary)
                }
            }
        } header: {
            Text("Weather Data")
        } footer: {
            Text("papaWeather uses Bureau of Meteorology data — no API key required. The nearest station to your location is selected automatically.")
        }
    }

    // MARK: - Radar Map

    @ViewBuilder
    private var radarSection: some View {
        Section {
            Toggle("Enable Radar Tab", isOn: $radarEnabled)
        } header: {
            Text("Radar Map")
        } footer: {
            Text("Shows a live precipitation radar map tab. Disabled by default as it uses third-party tile services.")
        }
    }

    // MARK: - About

    @ViewBuilder
    private var aboutSection: some View {
        Section {
        } footer: {
            HStack {
                Spacer()
                Text("papaWeather v\(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")")
                    .font(.footnote)
                    .foregroundStyle(.tertiary)
                Spacer()
            }
        }
    }
}

private struct WeeklyPlannerDayRow: View {
    let day: WeeklyActivityDay
    @Binding var activity: String
    let characterLimit: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(day.title)
                Spacer()
                Text("\(activity.count)/\(characterLimit)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }

            TextField("No plans", text: $activity, axis: .vertical)
                .lineLimit(3...5)
                .frame(minHeight: 88, alignment: .topLeading)
                .multilineTextAlignment(.leading)
                .textInputAutocapitalization(.sentences)
        }
        .padding(.vertical, 6)
    }
}
