---
name: radar-map
description: Use when working on the radar map tab in papaWeather — MapKit tile overlays, Rainbow.ai precipitation tiles, OpenWeatherMap weather layers, RadarSnapshotService, RadarTileTracker, map panning constraints, or RadarMapViewModel.
tools:
  - Read
  - Write
  - Edit
  - Bash
  - Glob
  - Grep
---

You are an expert in the papaWeather radar map system.

## Architecture

`RadarMapView` (SwiftUI) wraps `MapKitRadarView` (`UIViewRepresentable` MKMapView). State lives in `RadarMapViewModel` (`@Observable @MainActor`). Two tile overlay providers are swappable at runtime.

## Tile providers

### Rainbow.ai (`RainbowTileOverlay`)
- Tile URL: `https://api.rainbow.ai/tiles/v1/precip/{snapshot}/{forecastOffset}/{z}/{x}/{y}?token={key}&color=0`
- `snapshot` is an opaque integer ID fetched from `RadarSnapshotService`. It changes as new radar data arrives.
- `forecastOffset` is always `0` currently (`MapProviderType.frames` returns `[0]`, `supportsAnimation` is `false`).
- API key via `RainbowConfig.apiKey` (read from Info.plist, set via `RainbowConfig.xcconfig`).
- Tiles are cached: `URLRequest` uses `.returnCacheDataElseLoad`.
- **200 km radius culling**: `tileIntersectsRadius` clips tiles to a 200 km radius around the user, using the closest point on the tile bounding box (not tile centre) so boundary tiles are still fetched. Tiles fully outside are skipped with `result(nil, nil)`.

### OpenWeatherMap (`OpenWeatherMapTileOverlay`)
- Static weather layer tiles — no snapshot, no animation.
- Layer selected via `OWMLayer` enum; stored in `UserDefaults("owmLayer")`.
- API key via `OpenWeatherMapConfig.apiKey` (Info.plist / xcconfig).

## RadarSnapshotService

A Swift `actor` — all access is async. Fetches `https://api.rainbow.ai/tiles/v1/snapshot?token={key}` to get the current snapshot integer. Auto-refreshes every 600 seconds while Rainbow is the active provider; stops when switching to OWM.

## RadarTileTracker

`@Observable @MainActor` singleton. Counts in-flight tile requests (`activeRequests`). `begin()` / `end()` are called from the non-isolated `RainbowTileOverlay.loadTile` via `Task { @MainActor in }`. `isLoading` drives the tile-loading indicator in `RadarMapView`.

## Map constraints (Coordinator)

- Max pan radius: 200 km from user location.
- Max zoom out: `latitudeDelta` capped at `200_000 / 111_319.5` degrees.
- On constraint violation, `regionDidChangeAnimated` snaps the map back using `setRegion(_:animated:)` and a 500 ms `isSnappingBack` guard to prevent re-entry.
- `hasCenteredOnUser` ensures the map zooms in to 200 km around the user only once on first location fix.

## Switching providers

`RadarMapViewModel.switchProvider(to:)` stops animation, resets frame index, persists the choice to `UserDefaults("mapProvider")`, then calls `loadSnapshot()`. `MapKitRadarView.updateUIView` detects provider changes by checking the overlay type and replaces the overlay when needed.

## Adding a new tile provider

1. Add a case to `MapProviderType`.
2. Implement `makeTileOverlay` and `fetchSnapshot` for the new case.
3. Create a `MKTileOverlay` subclass if custom tile URL logic or culling is needed.
4. Add the overlay type check in `MapKitRadarView.updateUIView`'s `needsReplace` logic.
