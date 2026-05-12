//
//  RadarMapView.swift
//  papaWeather
//

import SwiftUI
import MapKit
import CoreLocation

// MARK: - MapKit UIViewRepresentable

struct MapKitRadarView: UIViewRepresentable {
    let provider: MapProviderType
    let snapshot: Int
    let forecastOffset: Int
    let owmLayer: OWMLayer
    let userCoordinate: CLLocationCoordinate2D?

    private static let fallback = CLLocationCoordinate2D(latitude: -37.8136, longitude: 144.9631)

    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        mapView.mapType = .standard
        mapView.showsCompass = true
        mapView.showsUserLocation = true
        mapView.isRotateEnabled = false
        let region = MKCoordinateRegion(
            center: Self.fallback,
            latitudinalMeters: 800_000,
            longitudinalMeters: 800_000
        )
        mapView.setRegion(region, animated: false)
        let overlay = provider.makeTileOverlay(snapshot: snapshot, forecastOffset: forecastOffset, owmLayer: owmLayer)
        (overlay as? RainbowTileOverlay)?.userCoordinate = userCoordinate
        mapView.addOverlay(overlay, level: .aboveLabels)
        return mapView
    }

    func updateUIView(_ mapView: MKMapView, context: Context) {
        context.coordinator.userCoordinate = userCoordinate

        if let coord = userCoordinate, !context.coordinator.hasCenteredOnUser {
            context.coordinator.hasCenteredOnUser = true
            let region = MKCoordinateRegion(
                center: coord,
                latitudinalMeters: 200_000,
                longitudinalMeters: 200_000
            )
            mapView.setRegion(region, animated: true)
        }

        let needsReplace: Bool
        switch provider {
        case .rainbow:
            let existing = mapView.overlays.compactMap { $0 as? RainbowTileOverlay }.first
            // Replace when snapshot changes OR when the coordinate first arrives so
            // any tiles fetched before location was known are re-evaluated.
            let coordBecameAvailable = existing?.userCoordinate == nil && userCoordinate != nil
            needsReplace = existing?.snapshot != snapshot
                || existing?.forecastOffset != forecastOffset
                || coordBecameAvailable
        case .openWeatherMap:
            let existing = mapView.overlays.compactMap { $0 as? OpenWeatherMapTileOverlay }.first
            needsReplace = existing?.layer != owmLayer
        }

        if !needsReplace {
            // Keep existing overlay but update its coordinate so future tile
            // requests use the latest location for the radius check.
            mapView.overlays.compactMap { $0 as? RainbowTileOverlay }.first?.userCoordinate = userCoordinate
            return
        }

        mapView.removeOverlays(mapView.overlays)
        let overlay = provider.makeTileOverlay(snapshot: snapshot, forecastOffset: forecastOffset, owmLayer: owmLayer)
        (overlay as? RainbowTileOverlay)?.userCoordinate = userCoordinate
        mapView.addOverlay(overlay, level: .aboveLabels)
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    @MainActor
    final class Coordinator: NSObject, MKMapViewDelegate {
        var hasCenteredOnUser = false
        var userCoordinate: CLLocationCoordinate2D? = nil
        private var isSnappingBack = false

        private static let maxRadiusMeters: Double = 200_000
        private static let maxLatitudeDelta: Double = 200_000 / 111_319.5

        nonisolated func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            guard let tileOverlay = overlay as? MKTileOverlay else {
                return MKOverlayRenderer(overlay: overlay)
            }
            let renderer = MKTileOverlayRenderer(tileOverlay: tileOverlay)
            renderer.alpha = 0.75
            return renderer
        }

        nonisolated func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
            Task { @MainActor in
                guard !self.isSnappingBack else { return }

                var newCenter = mapView.region.center
                var newSpan   = mapView.region.span
                var needsSnap = false

                if let origin = self.userCoordinate {
                    let originLoc = CLLocation(latitude: origin.latitude, longitude: origin.longitude)
                    let centerLoc = CLLocation(latitude: newCenter.latitude, longitude: newCenter.longitude)
                    if originLoc.distance(from: centerLoc) > Self.maxRadiusMeters {
                        newCenter = coordinate(from: origin,
                                               toward: newCenter,
                                               distance: Self.maxRadiusMeters)
                        needsSnap = true
                    }
                }

                if newSpan.latitudeDelta > Self.maxLatitudeDelta {
                    newSpan   = MKCoordinateSpan(latitudeDelta:  Self.maxLatitudeDelta,
                                                 longitudeDelta: Self.maxLatitudeDelta)
                    needsSnap = true
                }

                guard needsSnap else { return }

                self.isSnappingBack = true
                mapView.setRegion(MKCoordinateRegion(center: newCenter, span: newSpan), animated: true)
                try? await Task.sleep(for: .milliseconds(500))
                self.isSnappingBack = false
            }
        }
    }
}

// MARK: - Geographic helpers

private func coordinate(from origin: CLLocationCoordinate2D,
                        toward target: CLLocationCoordinate2D,
                        distance: Double) -> CLLocationCoordinate2D {
    let R    = 6_371_000.0
    let lat1 = origin.latitude  * .pi / 180
    let lon1 = origin.longitude * .pi / 180
    let lat2 = target.latitude  * .pi / 180
    let lon2 = target.longitude * .pi / 180

    let dLon = lon2 - lon1
    let y    = sin(dLon) * cos(lat2)
    let x    = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLon)
    let bearing = atan2(y, x)

    let d    = distance / R
    let φ2   = asin(sin(lat1) * cos(d) + cos(lat1) * sin(d) * cos(bearing))
    let λ2   = lon1 + atan2(sin(bearing) * sin(d) * cos(lat1),
                             cos(d) - sin(lat1) * sin(φ2))

    return CLLocationCoordinate2D(latitude:  φ2 * 180 / .pi,
                                  longitude: λ2 * 180 / .pi)
}

// MARK: - Radar Map View

struct RadarMapView: View {
    @State private var viewModel = RadarMapViewModel()
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack(alignment: .bottom) {
            MapKitRadarView(
                provider: viewModel.selectedProvider,
                snapshot: viewModel.currentSnapshot,
                forecastOffset: viewModel.frames[viewModel.selectedFrameIndex],
                owmLayer: viewModel.selectedOWMLayer,
                userCoordinate: viewModel.userCoordinate
            )
            .ignoresSafeArea()

            if viewModel.isLoading {
                loadingOverlay
            }

            if let error = viewModel.errorMessage {
                errorBanner(error)
            }

            if viewModel.selectedProvider.supportsAnimation {
                controlPanel
                    .padding(.horizontal, 16)
                    .padding(.bottom, 32)
            }

            refreshButton
            tileLoadingIndicator
        }
        .task { await viewModel.loadSnapshot() }
        .onDisappear { viewModel.stopAnimation() }
    }

    // MARK: - Provider Picker

    private var providerPicker: some View {
        Picker("Map source", selection: Binding(
            get: { viewModel.selectedProvider },
            set: { viewModel.switchProvider(to: $0) }
        )) {
            ForEach(MapProviderType.allCases, id: \.self) { provider in
                Text(provider.displayName).tag(provider)
            }
        }
        .pickerStyle(.segmented)
        .frame(maxWidth: 180)
    }

    // MARK: - Control Panel

    private var controlPanel: some View {
        HStack(spacing: 14) {
            Button(action: viewModel.toggleAnimation) {
                Image(systemName: viewModel.isAnimating ? "pause.fill" : "play.fill")
                    .font(.system(size: 20, weight: .semibold))
                    .frame(width: 36, height: 36)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.primary)

            Slider(
                value: Binding(
                    get: { Double(viewModel.selectedFrameIndex) },
                    set: { newValue in
                        viewModel.stopAnimation()
                        viewModel.selectedFrameIndex = Int(newValue.rounded())
                    }
                ),
                in: 0...Double(viewModel.frames.count - 1),
                step: 1
            )
            .tint(.cyan)
            .disabled(viewModel.isLoading)

            Text(viewModel.formattedFrameTime)
                .font(.transit(13, weight: .semibold))
                .foregroundStyle(.primary)
                .frame(minWidth: 60, alignment: .trailing)
                .monospacedDigit()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background { panelBackground }
    }

    @ViewBuilder
    private var panelBackground: some View {
        if #available(iOS 26, *) {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.ultraThinMaterial)
                .glassEffect(in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        } else {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.ultraThinMaterial)
        }
    }

    // MARK: - Refresh Button

    private var refreshButton: some View {
        VStack(spacing: 8) {
            HStack {
                providerPicker
                    .padding(.top, 16)
                    .padding(.leading, 16)
                Spacer()
                Button {
                    Task { await viewModel.loadSnapshot() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 16, weight: .semibold))
                        .frame(width: 40, height: 40)
                        .background { refreshButtonBackground }
                }
                .buttonStyle(.plain)
                .foregroundStyle(.primary)
                .disabled(viewModel.isLoading)
                .padding(.top, 16)
                .padding(.trailing, 16)
            }

            if viewModel.selectedProvider == .openWeatherMap {
                layerPicker
                    .padding(.horizontal, 16)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }

            Spacer()
        }
        .animation(.easeInOut(duration: 0.2), value: viewModel.selectedProvider)
    }

    private var layerPicker: some View {
        HStack(spacing: 8) {
            ForEach(OWMLayer.allCases, id: \.self) { layer in
                let isSelected = viewModel.selectedOWMLayer == layer
                Button {
                    viewModel.switchOWMLayer(to: layer)
                } label: {
                    Text(layer.displayName)
                        .font(.transit(12, weight: isSelected ? .semibold : .regular))
                        .foregroundStyle(isSelected ? .white : .primary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background {
                            Capsule()
                                .fill(isSelected ? Color.cyan : Color.primary.opacity(0.12))
                        }
                }
                .buttonStyle(.plain)
                .animation(.easeInOut(duration: 0.15), value: isSelected)
            }
        }
    }

    @ViewBuilder
    private var refreshButtonBackground: some View {
        if #available(iOS 26, *) {
            Circle()
                .fill(.ultraThinMaterial)
                .glassEffect(in: Circle())
        } else {
            Circle()
                .fill(.ultraThinMaterial)
        }
    }

    // MARK: - Tile loading indicator

    private var tileLoadingIndicator: some View {
        VStack {
            Spacer()
            HStack {
                if RadarTileTracker.shared.isLoading {
                    HStack(spacing: 6) {
                        ProgressView()
                            .scaleEffect(0.75)
                            .tint(.primary)
                        Text(viewModel.selectedProvider.fetchingLabel)
                            .font(.transit(12, weight: .medium))
                            .foregroundStyle(.primary)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background {
                        Capsule()
                            .fill(.ultraThinMaterial)
                    }
                    .transition(.opacity.combined(with: .scale(scale: 0.9, anchor: .leading)))
                }
                Spacer()
            }
            .padding(.leading, 16)
            .padding(.bottom, 100)
        }
        .animation(.easeInOut(duration: 0.25), value: RadarTileTracker.shared.isLoading)
    }

    // MARK: - Overlays

    private var loadingOverlay: some View {
        ZStack {
            Color.black.opacity(0.25).ignoresSafeArea()
            VStack(spacing: 12) {
                ProgressView()
                    .scaleEffect(1.4)
                    .tint(.white)
                Text(viewModel.selectedProvider.loadingLabel)
                    .font(.transit(15, weight: .medium))
                    .foregroundStyle(.white)
            }
        }
    }

    private func errorBanner(_ message: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.yellow)
            Text(message)
                .font(.transit(13, weight: .medium))
                .foregroundStyle(.primary)
                .lineLimit(2)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(.ultraThinMaterial)
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 120)
    }
}
