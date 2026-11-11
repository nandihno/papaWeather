# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Building and running

Open `papaWeather/papaWeather.xcodeproj` in Xcode and run on a simulator or device. There are no Swift packages, CocoaPods, or other dependency managers — all frameworks are Apple system frameworks.

Build from the command line:
```bash
xcodebuild -project papaWeather/papaWeather.xcodeproj \
           -scheme papaWeather \
           -destination 'generic/platform=iOS Simulator' \
           CODE_SIGNING_ALLOWED=NO \
           build
```

There are no automated tests in the project.

## API keys

Two API keys are required at build time and must be configured before the radar tab works:

- **Rainbow.ai (radar)** — set `RAINBOW_API_KEY` in `papaWeather/papaWeather/Config/RainbowConfig.xcconfig`, then assign that xcconfig to both Debug and Release build configurations in Xcode project settings. The xcconfig injects the key into Info.plist; `RainbowConfig.swift` reads it via `Bundle.main.infoDictionary`.
- **OpenWeatherMap (map layer)** — set `OWM_API_KEY` using the same xcconfig pattern; `OpenWeatherMapConfig.swift` reads it the same way.
- **Claude AI (optional, runtime)** — the user enters their own `sk-ant-...` key in Settings at runtime; stored in `@AppStorage("claudeApiKey")`.

## Architecture

### Data flow

`WeatherView` is the single root view. On first appear it calls `WeatherService.shared.fetchWeatherBundle()`, which fires five concurrent `async let` tasks and returns a `WeatherBundle`:

1. Current observations from the nearest BOM station (picked from `stations.json` by haversine distance via `WeatherStation.nearest`)
2. 7-day daily forecast from `api.weather.bom.gov.au/v1` (location resolved via geohash)
3. Hourly forecast from the same BOM v1 API
4. Astronomical data (10-day sunrise/sunset) from `api.geodesyapps.ga.gov.au`
5. Reverse-geocoded locality name via MapKit / CoreLocation

Forecast and astronomical fetches are all `try?` — they degrade gracefully if the BOM location lookup fails. Observations use the nearest station and will throw if no stations are available.

### Two-layer model pattern

All JSON decoding uses `BOM*` structs in `Models/BOMModels.swift` that mirror the raw API shapes exactly (snake_case via `CodingKeys`). `WeatherService` then maps these into the clean domain models in `Models/WeatherModels.swift` (`WeatherInfo`, `DailyForecastInfo`, `HourlyForecastInfo`, `AstronomicalInfo`). Views only ever touch the domain models.

### AI analysis

Two interchangeable providers share `ClaudeAnalysisSpec` / `WeatherAnalysisSpecBuilder`:

- **Apple Intelligence** (`AppleIntelligenceService`) — uses `FoundationModels.LanguageModelSession` for on-device inference. Also powers inline pressure and humidity insight cards shown directly in the Station tab.
- **Claude API** (`ClaudeService`) — calls `api.anthropic.com/v1/messages` with `claude-haiku-4-5`, requires user-supplied API key. 

The provider is selected via `@AppStorage("aiProvider")` and toggled in `SettingsView`.

### Radar map

`RadarMapView` wraps a `UIViewRepresentable` MKMapView. Two tile overlay providers:

- **Rainbow.ai** — precipitation tiles at `api.rainbow.ai/tiles/v1/precip/{snapshot}/{offset}/{z}/{x}/{y}`. `RadarSnapshotService` (an `actor`) fetches the current snapshot ID and auto-refreshes every 10 minutes. Tiles are culled to a 200 km radius around the user to avoid unnecessary requests.
- **OpenWeatherMap** — weather layer tiles; no animation, no snapshot concept.

`RadarTileTracker` (an `@Observable` singleton) counts in-flight tile requests to show/hide a loading indicator without coupling the tile overlay to SwiftUI.

### Theme system

`AppTheme` / `ThemeSet` / `ThemePalette` provide a single source of truth for colours. `ThemePalette` is injected as an `EnvironmentKey` (`\.themePalette`) so any view can read it without prop drilling. Apply to a screen with `.screenTheme(AppTheme.weather)`. Apply to a card with `.transitCardStyle()`. The `Font.transit(_:weight:)` helper uses `.system(..., design: .rounded)` throughout.

`WeatherBackground.gradient(for:colorScheme:)` blends the condition-driven colors into the light or dark palette for the weather tabs. The station conditions card uses a dark surface with light text in either appearance.

### Adaptive weather UI

- The Station tab stacks current conditions, the briefing, and trends at compact widths. When there is room, the overview and the trends scroll independently in two panes. On iOS 27.1 and later, SwiftUI's split `ArrangementView` places the panes on either side of an active fold. Unfolded layouts use one column at accessibility text sizes.
- The native tab bar and toolbar move with the system. Warnings precedes Astro and the optional Radar tab so its badge stays visible when the system groups extra tabs under More. The selected tab, active location, briefing, and pressure guide state live outside the Station layout. Refresh is available in the toolbar and by pulling down on a weather tab.
- Radar keeps the map full bleed. Its source, layer, and refresh controls stay together on one side when a vertical fold divides the display. The source and layer use menus so they fit narrow windows.

When checking layout changes in Device Hub, run the app on a standard iPhone and on the Duo's outer display, then open and partially fold the inner display in both orientations. Switch tabs and expand the pressure guide before changing poses to check continuity. Check narrow Split View, accessibility text sizes, dark appearance, and a Radar provider configured with a test key. Verify that the location menu and Settings remain reachable in every pose.

The simulator smoke test covered the Duo's outer, flat inner, and both partially folded layouts on iOS 27.2. It exercised tab and Settings continuity and the Radar source and layer controls. An iPhone 18 Pro running iOS 27.0 loaded weather for a simulated Melbourne location and displayed the Station, Hourly, Daily, Warnings, and Astro screens. The Station view was also checked in dark appearance at an accessibility text size. Physical devices, narrow Split View, VoiceOver, and live Radar tile data still need verification.

### State persistence

- Custom weather stations — `WeatherStationStore` persists to App Group-backed defaults (`papaWeather.customWeatherStations`).
- Selected map provider and OWM layer — `UserDefaults` keys `mapProvider` and `owmLayer`.
- Claude API key and AI provider choice — `@AppStorage`.
- Default stations — bundled `stations.json` decoded lazily via `WeatherStation.loadDefaults()`.

### iOS 27 Spotlight and App Intents integration

- `WeatherWarningEntity` is an App Intents shadow model conforming to `IndexedEntity`; its searchable content is indexed through Core Spotlight, with severe BOM warnings receiving higher ranking.
- `WeatherWarningEntityQuery` resolves indexed warnings from the shared cache and adopts iOS 27 `IndexedEntityQuery` reindex callbacks.
- `WeatherWarningIndexStore` stores the latest successful BOM warning list and fetch coordinate in the App Group snapshot; `WeatherWarningSpotlightIndexer` replaces the Spotlight warning set after a successful weather refresh.
- Spotlight indexing is best-effort and runs in the background through `refreshInBackground()`; weather refresh UI and App Intent responses must not wait on the system indexing service.
- `WeatherLocationEntity` is an App Intents shadow model for the current device location and saved locations. `WeatherLocationEntityQuery` supports identifier resolution, suggestions, and free-text matching.
- `GetCurrentConditionsIntent`, `GetForecastIntent`, and `GetWarningsIntent` provide the first read-only system actions. `PapaWeatherAppShortcuts` registers their Siri and Shortcuts phrases.
- `SharedAppStorage` uses the `group.org.nando.papaWeather` App Group and migrates the existing saved-location and custom-station keys from standard defaults. The signed target entitlement must continue to include that group before adding an App Intents extension or widget.
- Phases 1 through 3 are implemented in the main app target. `WeatherView` identifies the active `WeatherLocationEntity`; visible warning cards and the warning detail sheet identify their `WeatherWarningEntity`. A dedicated App Intents extension and later long-running/background work remain as separate phases described in `27features.md`.
