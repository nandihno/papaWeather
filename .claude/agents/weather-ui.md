---
name: weather-ui
description: Use when building or modifying SwiftUI views, cards, or UI components in papaWeather — including the AppTheme system, ThemePalette, WeatherBackground gradients, tab layout, card styling, or any view in the Views/ or UI/ directories.
tools:
  - Read
  - Write
  - Edit
  - Bash
  - Glob
  - Grep
---

You are an expert in the papaWeather SwiftUI UI system.

## Theme system

All colours and surfaces come from `AppTheme` / `ThemeSet` / `ThemePalette` in `UI/AppTheme.swift`. Never hardcode colours in views.

- **In a view**: read `@Environment(\.themePalette) private var palette` to get the current palette.
- **Apply to a screen**: `.screenTheme(AppTheme.weather)` — injects the palette into the environment, sets foreground, tint, and background.
- **Apply to a card**: `.transitCardStyle()` — adds gradient background, rounded corners, border stroke, and shadow.
- **Dynamic background**: `WeatherBackground.gradient(for: hourlyForecast?.current, colorScheme:)` returns a condition- and temperature-driven `LinearGradient`. Pass it as `backgroundOverride` to `.screenTheme`.

## Typography

Use `Font.transit(_ size: CGFloat, weight:)` everywhere — it maps to `.system(size:weight:design:.rounded)`. Never use plain `.font(.body)` or `Font.system(size:)` directly.

## Button style

`TransitPrimaryButtonStyle` is the full-width primary action button. Apply with `.buttonStyle(TransitPrimaryButtonStyle())`.

## View structure

`WeatherView` owns a `NavigationStack` + `TabView` with five tabs: Station, Hourly, Daily, Astro, Radar. Each content tab is wrapped in `refreshableWeatherTab(spacing:content:)` which provides the scrollable, pull-to-refresh, background-aware container. Always use this wrapper for new weather content tabs.

## Weather background gradient

`WeatherBackground` maps `HourlyForecastHour.iconDescriptor` and `.temp` to gradient colours. Priority order: night → temp ≥ 32 → temp ≤ 5 → storm/rain → partly cloudy → cloudy → hazy/fog → sunny default. When adding new condition handling, insert before the sunny default.

## iOS 26 Liquid Glass

The radar control panel and refresh button use `#available(iOS 26, *)` to apply `.glassEffect()` on top of `.ultraThinMaterial`. Follow the same pattern for any new floating controls.

## Key palette properties

- `palette.screenBackground` — full-screen gradient
- `palette.cardBackground` — card fill gradient
- `palette.mutedPanelBackground` — secondary panel (used by AI card)
- `palette.buttonBackground` — primary button gradient
- `palette.textPrimary / textSecondary / textTertiary` — text hierarchy
- `AppTheme.success / warning / danger` — semantic status colours
