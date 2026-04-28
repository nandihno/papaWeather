//
//  WeatherStationsView.swift
//  papaWeather
//

import SwiftUI

// MARK: - Station list

struct WeatherStationsView: View {
    @State private var store = WeatherStationStore.shared
    @State private var showAdd = false

    var body: some View {
        List {
            Section {
                ForEach(WeatherStation.defaults) { station in
                    StationRow(station: station)
                }
            } header: {
                Text("Built-in  (\(WeatherStation.defaults.count))")
            } footer: {
                Text("These stations are bundled with the app and cannot be removed.")
            }

            Section {
                if store.custom.isEmpty {
                    Text("No custom stations yet — tap + to add one.")
                        .font(.subheadline)
                        .foregroundStyle(.tertiary)
                } else {
                    ForEach(store.custom) { station in
                        StationRow(station: station)
                    }
                    .onDelete { store.delete(offsets: $0) }
                }
            } header: {
                Text("Custom  (\(store.custom.count))")
            } footer: {
                Text("The nearest station from both lists is selected automatically. Swipe left to delete a custom station.")
            }
        }
        .navigationTitle("Weather Stations")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { showAdd = true } label: { Image(systemName: "plus") }
            }
        }
        .sheet(isPresented: $showAdd) {
            AddStationView()
        }
    }
}

// MARK: - Station row

struct StationRow: View {
    let station: WeatherStation

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .center, spacing: 6) {
                Text(station.state)
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.accentColor.opacity(0.12))
                    .foregroundStyle(Color.accentColor)
                    .clipShape(RoundedRectangle(cornerRadius: 4))

                Text(station.title)
                    .font(.body)
            }

            Text(String(format: "%.4f,  %.4f", station.lat, station.lon))
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Add Station sheet

struct AddStationView: View {
    @State private var store = WeatherStationStore.shared
    @Environment(\.dismiss) private var dismiss

    @State private var selectedState: AustralianState = .vic
    @State private var title   = ""
    @State private var url     = ""
    @State private var latText = ""
    @State private var lonText = ""

    private var lat: Double? {
        guard let v = Double(latText), (-90...90).contains(v) else { return nil }
        return v
    }
    private var lon: Double? {
        guard let v = Double(lonText), (-180...180).contains(v) else { return nil }
        return v
    }
    private var urlIsValid: Bool {
        URL(string: url.trimmingCharacters(in: .whitespaces)) != nil && url.hasPrefix("https://")
    }
    private var isValid: Bool {
        !title.trimmingCharacters(in: .whitespaces).isEmpty && urlIsValid && lat != nil && lon != nil
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("State", selection: $selectedState) {
                        ForEach(AustralianState.allCases) { s in
                            Text("\(s.rawValue) — \(s.fullName)").tag(s)
                        }
                    }
                    TextField("Station name", text: $title)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.words)
                } header: {
                    Text("Station Details")
                }

                Section {
                    coordinateField(label: "Latitude",  placeholder: "e.g. -37.9",  text: $latText,
                                    isOK: lat != nil || latText.isEmpty)
                    coordinateField(label: "Longitude", placeholder: "e.g. 144.8", text: $lonText,
                                    isOK: lon != nil || lonText.isEmpty)
                } header: {
                    Text("Coordinates")
                } footer: {
                    Text("Latitude: −90 to 90  ·  Longitude: −180 to 180\nNegative latitude = Southern Hemisphere.")
                }

                Section {
                    TextField("https://www.bom.gov.au/fwo/...", text: $url)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .foregroundStyle(urlIsValid || url.isEmpty ? Color.primary : .red)
                } header: {
                    Text("BOM Data URL")
                } footer: {
                    Text("Find your station at bom.gov.au → Observations.\nFormat: https://www.bom.gov.au/fwo/IDX60901/IDX60901.NNNNN.json")
                }
            }
            .navigationTitle("Add Station")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel", role: .cancel) { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") { save() }
                        .fontWeight(.semibold)
                        .disabled(!isValid)
                }
            }
        }
    }

    @ViewBuilder
    private func coordinateField(label: String, placeholder: String,
                                 text: Binding<String>, isOK: Bool) -> some View {
        HStack {
            Text(label).foregroundStyle(.secondary)
            Spacer()
            TextField(placeholder, text: text)
                .multilineTextAlignment(.trailing)
                .keyboardType(.numbersAndPunctuation)
                .foregroundStyle(isOK ? Color.primary : .red)
                .frame(maxWidth: 140)
        }
    }

    private func save() {
        guard let lat, let lon else { return }
        store.add(WeatherStation(
            state: selectedState.rawValue,
            title: title.trimmingCharacters(in: .whitespaces),
            url:   url.trimmingCharacters(in: .whitespaces),
            lat:   lat,
            lon:   lon
        ))
        dismiss()
    }
}
