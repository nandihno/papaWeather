//
//  SettingsView.swift
//  papaWeather
//

import SwiftUI

struct SettingsView: View {
    @AppStorage("claudeApiKey") private var claudeApiKey: String = ""
    @AppStorage("aiProvider") private var aiProviderRaw: String = AIProvider.appleIntelligence.rawValue
    @AppStorage("radarEnabled") private var radarEnabled: Bool = false
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
