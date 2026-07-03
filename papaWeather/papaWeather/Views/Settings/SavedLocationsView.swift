//
//  SavedLocationsView.swift
//  papaWeather
//

import SwiftUI
import MapKit
import CoreLocation
import Combine

// MARK: - Saved Locations list

struct SavedLocationsView: View {
    @State private var store = LocationSelectionStore.shared
    @State private var showAdd = false

    var body: some View {
        List {
            Section {
                if store.saved.isEmpty {
                    Text("No saved locations yet — tap + to add a suburb.")
                        .font(.subheadline)
                        .foregroundStyle(.tertiary)
                } else {
                    ForEach(store.saved) { location in
                        SavedLocationRow(location: location)
                    }
                    .onDelete { store.delete(offsets: $0) }
                }
            } header: {
                Text("Saved Locations  (\(store.saved.count))")
            } footer: {
                Text("Adding a suburb captures its coordinates. Switch between these and “My Location” from the title bar on any tab. Swipe left to delete.")
            }
        }
        .navigationTitle("Locations")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { showAdd = true } label: { Image(systemName: "plus") }
            }
        }
        .sheet(isPresented: $showAdd) {
            AddLocationView()
        }
    }
}

// MARK: - Saved location row

struct SavedLocationRow: View {
    let location: SavedLocation

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .center, spacing: 6) {
                if let state = location.state, !state.isEmpty {
                    Text(state)
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.accentColor.opacity(0.12))
                        .foregroundStyle(Color.accentColor)
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                }

                Text(location.name)
                    .font(.body)
            }

            Text(String(format: "%.4f,  %.4f", location.lat, location.lon))
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Search model

/// Drives MapKit type-ahead, biased to Australia. Delegate callbacks land on the
/// main thread, so plain `ObservableObject` + `@Published` is the right fit here.
final class LocationSearchModel: NSObject, ObservableObject, MKLocalSearchCompleterDelegate {
    @Published var results: [MKLocalSearchCompletion] = []

    private let completer = MKLocalSearchCompleter()

    override init() {
        super.init()
        completer.delegate = self
        completer.resultTypes = .address
        // Bias results to Australia (centred on the continent, generous span).
        completer.region = MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: -25.27, longitude: 133.77),
            span: MKCoordinateSpan(latitudeDelta: 45, longitudeDelta: 50)
        )
    }

    func search(_ fragment: String) {
        let trimmed = fragment.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            results = []
            return
        }
        completer.queryFragment = trimmed
    }

    func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        // Keep Australian matches only — region only biases, it doesn't restrict.
        results = completer.results.filter { $0.subtitle.localizedCaseInsensitiveContains("Australia") }
    }

    func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        results = []
    }
}

// MARK: - Add location sheet

struct AddLocationView: View {
    @State private var store = LocationSelectionStore.shared
    @StateObject private var search = LocationSearchModel()
    @Environment(\.dismiss) private var dismiss

    @State private var queryText = ""
    @State private var isResolving = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            List {
                if let errorMessage {
                    Section {
                        Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                            .font(.subheadline)
                            .foregroundStyle(.orange)
                    }
                }

                Section {
                    ForEach(search.results, id: \.self) { completion in
                        Button {
                            Task { await addLocation(completion) }
                        } label: {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(completion.title)
                                    .font(.body)
                                    .foregroundStyle(.primary)
                                if !completion.subtitle.isEmpty {
                                    Text(completion.subtitle)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .disabled(isResolving)
                    }
                } footer: {
                    if queryText.trimmingCharacters(in: .whitespaces).isEmpty {
                        Text("Search for an Australian suburb, town or postcode. Its coordinates are captured automatically.")
                    } else if search.results.isEmpty {
                        Text("No Australian matches yet — keep typing.")
                    }
                }
            }
            .searchable(
                text: $queryText,
                placement: .navigationBarDrawer(displayMode: .always),
                prompt: "Suburb, town or postcode"
            )
            .onChange(of: queryText) { _, newValue in
                search.search(newValue)
            }
            .overlay {
                if isResolving {
                    ProgressView("Adding…")
                        .padding(20)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                }
            }
            .navigationTitle("Add Location")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel", role: .cancel) { dismiss() }
                }
            }
        }
    }

    private func addLocation(_ completion: MKLocalSearchCompletion) async {
        isResolving = true
        errorMessage = nil
        defer { isResolving = false }

        do {
            let request = MKLocalSearch.Request(completion: completion)
            let response = try await MKLocalSearch(request: request).start()
            guard let item = response.mapItems.first else {
                errorMessage = "Couldn't locate that place. Try another result."
                return
            }

            let placemark = item.placemark
            if let iso = placemark.isoCountryCode, iso != "AU" {
                errorMessage = "Please pick a location within Australia."
                return
            }

            let coordinate = placemark.coordinate
            let location = SavedLocation(
                name: completion.title,
                state: Self.stateAbbreviation(from: placemark),
                lat: coordinate.latitude,
                lon: coordinate.longitude
            )
            store.add(location)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Normalises MapKit's administrative-area string to a two/three-letter AU state code.
    private static func stateAbbreviation(from placemark: CLPlacemark) -> String? {
        guard let admin = placemark.administrativeArea, !admin.isEmpty else { return nil }
        if let match = AustralianState.allCases.first(where: {
            $0.rawValue.caseInsensitiveCompare(admin) == .orderedSame ||
            $0.fullName.caseInsensitiveCompare(admin) == .orderedSame
        }) {
            return match.rawValue
        }
        return admin
    }
}
