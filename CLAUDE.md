# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Building and running

Open `papaWeather/papaWeather.xcodeproj` in Xcode and run on a simulator or device. There are no Swift packages, CocoaPods, or other dependency managers — all frameworks are Apple system frameworks.

Build from the command line:
```bash
xcodebuild -project papaWeather/papaWeather.xcodeproj \
           -scheme papaWeather \
           -destination 'platform=iOS Simulator,name=iPhone 16' \
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

`WeatherBackground.gradient(for:colorScheme:)` returns a condition- and temperature-driven `LinearGradient` used as the dynamic screen background — it reads the current `HourlyForecastHour` icon descriptor and temperature.

### State persistence

- Custom weather stations — `WeatherStationStore` persists to `UserDefaults` (`papaWeather.customWeatherStations`).
- Selected map provider and OWM layer — `UserDefaults` keys `mapProvider` and `owmLayer`.
- Claude API key and AI provider choice — `@AppStorage`.
- Default stations — bundled `stations.json` decoded lazily via `WeatherStation.loadDefaults()`.
