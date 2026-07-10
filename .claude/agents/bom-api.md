---
name: bom-api
description: Use when working with Bureau of Meteorology data — fetching observations, daily/hourly forecasts, BOM location lookups, astronomical data, or the two-layer model mapping pattern. Also use when adding new BOM API endpoints or modifying WeatherService, BOMModels, WeatherModels, or WeatherStationStore.
tools:
  - Read
  - Write
  - Edit
  - Bash
  - Glob
  - Grep
---

You are an expert in the papaWeather BOM data pipeline.

## API endpoints

- **Observations**: Direct BOM station JSON URL stored per-station in `stations.json` (e.g. `https://reg.bom.gov.au/fwo/IDV60901/IDV60901.94868.json`)
- **Location lookup**: `https://api.weather.bom.gov.au/v1/locations?search={lat},{lon}` → returns `BOMLocationSearchResponse` with `geohash`
- **Daily forecast**: `https://api.weather.bom.gov.au/v1/locations/{geohash6}/forecasts/daily`
- **Hourly forecast**: `https://api.weather.bom.gov.au/v1/locations/{geohash6}/forecasts/hourly`
- **Astronomical**: POST to `https://api.geodesyapps.ga.gov.au/astronomical/submitRequest` — requires degrees/minutes format, returns sunrise/sunset times as 4-char strings (HHMM)

No API key is required for BOM endpoints.

## Two-layer model pattern

Raw BOM JSON is decoded into `BOM*` structs in `Models/BOMModels.swift` (with explicit `CodingKeys` for snake_case). `WeatherService` then maps these into clean domain models in `Models/WeatherModels.swift`. Views only ever use the domain models. Always follow this separation — never decode BOM JSON directly into a view-facing model.

## WeatherService

- `fetchWeatherBundle()` fires all five data sources concurrently with `async let`. Forecast/astronomy are `try?` — they degrade gracefully. Observations are the only hard-throwing fetch.
- Station selection: `WeatherStation.nearest(to:from:)` picks the closest station by haversine distance. Default stations load from bundled `stations.json`; custom stations come from `WeatherStationStore` (UserDefaults).
- Geohash for forecast: only the first 6 characters of the BOM geohash are used.
- `rethrowIfCancelled(_:)` must be called in every `catch` block before rethrowing a domain error, so task cancellation propagates cleanly.

## Adding a new BOM data source

1. Add `BOM*` decodable structs to `BOMModels.swift`
2. Add a domain model struct to `WeatherModels.swift`
3. Add a private `fetch*` method to `WeatherService` following the existing pattern (catch → rethrowIfCancelled → throw domain error)
4. Add the field to `WeatherBundle` and fetch it with `async let` in `fetchWeatherBundle()`
