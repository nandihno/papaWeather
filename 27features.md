# iOS 27 / App Intents Integration Analysis — papaWeather

**Date:** 2026-09-15
**Question:** Can papaWeather expose its data to the new Siri AI in iOS 27 via App Intents?
**Short answer:** Yes, but not the way you'd expect. There is no weather schema domain, so the route is Spotlight semantic indexing, not a schema contract.

---

## 1. Environment verified

| Item | Value |
|---|---|
| Xcode | 27.0 (build 27A266a) |
| SDK | `iPhoneOS27.0.sdk` |
| Deployment target | `IPHONEOS_DEPLOYMENT_TARGET = 27.0` (`project.pbxproj:194`, `:252`) |
| Swift version setting | `SWIFT_VERSION = 5.0` (`project.pbxproj:295`, `:333`) |
| Targets | 1 — single app target. No widget/AppIntents extension. |
| App Group | **None** (`com.apple.security.application-groups` count = 0) |
| Existing App Intents adoption | **Zero** — no `AppIntent`, `AppEntity`, `AppShortcutsProvider`, or `IndexedEntity` in the codebase |

Findings below were taken from the installed SDK's `AppIntents.swiftinterface` (16,797 lines) and Apple's documentation JSON endpoints, not from model recall — iOS 27 postdates the assistant's training cutoff.

---

## 2. Headline finding: there is no weather schema domain

Assistant schemas are the contract that lets Apple Intelligence and Siri AI understand an app's actions and content conversationally. The **complete** list of domains in iOS 27:

**Primary domains**
`audio`, `calendar`, `camera`, `clock`, `mail`, `maps`, `messages`, `notes`, `phone`, `photos`, `reminders`, `system-and-in-app-search`

**Single-purpose domains**
`assistant` (side-button action — **Japan only**), `visual-intelligence`

**Shortcuts-specific domains**
`books`, `browser`, `files`, `journaling`, `presentation`, `reader`, `spreadsheet`, `whiteboard`, `word-processor`

Verification: `grep -ic "weather\|forecast"` against `AppIntents.swiftinterface` returns **0**.

### Implications

- `@AppIntent(schema: .weather.…)` **does not exist**. There is nothing to conform to.
- Apple's own Weather app owns generic routing for "what's the temperature". papaWeather cannot win that query by declaring a schema.
- The only broadly-applicable domain is `.system`. Apple's docs state it explicitly:

  > Unlike other domains that target a specific app category, the `.system` domain applies broadly. Any app that enables searching or opening content can adopt these schemas.

  That yields `.system.search` and `.system.open` — useful, but nothing weather-aware.

---

## 3. The route that does work: Spotlight semantic indexing

From Apple's *Apple Intelligence and Siri AI* overview:

> Apple Intelligence uses the semantic search capabilities of Spotlight to find your app's content, even when someone describes it vaguely.

**This mechanism is domain-agnostic.** Conform entities to `IndexedEntity`, index them into a named `CSSearchableIndex`, and Apple Intelligence can reason over that content with no schema involved.

This matters because papaWeather holds data Apple's Weather app does not:

- BOM station observations (nearest-station, not model-interpolated)
- **BOM warnings** — text-heavy, and exactly the kind of content humans describe vaguely
- Rainbow.ai radar
- Geodesy sunrise/sunset
- The weekly activity planner

BOM warnings are the strongest single candidate. "Is there a flood warning near me?" is a semantic-search query, not a schema query.

The five documented steps Apple lists for Apple Intelligence integration:

1. **Index entities** to make them available in Spotlight (semantic search)
2. **Choose transferable types** — `Transferable` / `IntentValueRepresentation` for cross-app movement
3. **Adopt schemas** — *not available to us for weather; `.system` only*
4. **Associate entities with views** — onscreen context, so "this warning" resolves
5. **Donate actions and content** — behavioural cues for prediction

Four of the five are open to papaWeather.

---

## 4. What's genuinely new in iOS 27

44 iOS-27-gated declarations were found. The relevant ones:

### `IndexedEntityQuery` (iOS 27 / macOS 27 / visionOS 27)
```swift
public protocol IndexedEntityQuery: EntityQuery where Self.Entity: IndexedEntity {
    func reindexEntities(for identifiers: [Self.Entity.ID],
                         indexDescription: CSSearchableIndexDescription) async throws
    func reindexAllEntities(indexDescription: CSSearchableIndexDescription) async throws
}
```
The system asks *you* to refresh the index. Weather data goes stale constantly — this is the difference between Siri quoting yesterday's warning and today's. **Most important new API for this app.**

### Async indexed property getters (iOS 27)
```swift
extension EntityProperty where Value.ValueType: _IntentValueRepresentable {
    convenience init<Entity>(identifier: String,
                             indexingKey: PartialKeyPath<CSSearchableItemAttributeSet>,
                             asyncGetter: @escaping @Sendable (Entity) async throws -> Value)
    convenience init<Entity>(identifier: String,
                             customIndexingKey: CSCustomAttributeKey,
                             asyncGetter: @escaping @Sendable (Entity) async throws -> Value)
    // + title: variants of both
}
```
Lets an indexed property require a BOM fetch without blocking.

### `associateAppEntity(_:priority:) async` (iOS 27)
Async variant on `CSSearchableItemAttributeSet`. `priority` elevates items in Spotlight suggestions and results — use it to rank severe warnings (`WeatherWarningInfo.isSevere`) above routine ones.

### `LongRunningIntent` (iOS 27)
```swift
public protocol LongRunningIntent: ProgressReportingIntent {}

extension LongRunningIntent {
    func performBackgroundTask<T>(options: LongRunningTaskOptions = [],
                                  operation: @escaping () async throws -> T) async throws -> T
    func performBackgroundTask<T>(options: LongRunningTaskOptions = [],
                                  operation: @escaping () async throws -> T,
                                  onCancel: @escaping @Sendable (IntentCancellationReason) -> Void
                                 ) async throws -> T where Self: CancellableIntent
}

public struct LongRunningTaskOptions: OptionSet, Sendable {
    public static let requiresGPU: LongRunningTaskOptions
}
```
Lets an intent outlive the foreground — fits the five-concurrent-`async let` `fetchWeatherBundle()`.

### `IntentResponseStream<Value>` (iOS 27)
Streaming intent responses.

### `SystemShortcut` / `RunSystemShortcutIntent` (iOS 27)
iPhone-only — explicitly `@available(macOS, unavailable)`, `tvOS/watchOS/visionOS` unavailable.

### `IntentExecutionTargets` (iOS 27)
OptionSet controlling where an intent may execute.

---

## 5. ⚠️ Trap: `_ModelDelegationIntent` is private SPI

The SDK contains:

```swift
@_documentation(visibility: internal)
public protocol _ModelDelegationIntent: SystemIntent
    where Self.PerformResult.Value == _ModelDelegationResult { ... }

public macro _ModelDelegationIntent
public struct _ModelDelegationResult
public struct _ModelDelegationFeatures
public enum _ModelDelegationConfiguration
public enum _ModelDelegationIntentEnabledStatus
// plus: var systemAssistant, var supportedFeatures, var enabledStatus
```

This looks **exactly** like "let the system model answer questions using my app" — the capability this analysis set out to find. It is underscore-prefixed and marked `@_documentation(visibility: internal)`, i.e. **private SPI**.

**Do not build on it.** It will fail App Review and can change or vanish without notice. If Apple promotes it to public API, that is the thing to watch for papaWeather.

---

## 6. Proposed architecture

### Entities — shadow models only

Never conform `WeatherWarningInfo`, `SavedLocation`, etc. directly; those carry app lifecycle concerns that conflict with intent lifecycle.

| Entity | Source | Notes |
|---|---|---|
| **`WeatherWarningEntity`** | `WeatherWarningInfo` (`Models/WeatherModels.swift:196`) | `IndexedEntity`. `@ComputedProperty(indexingKey: \.contentDescription)` over the warning body; `attributeSet` carries lat/lon. Use `associateAppEntity(priority:)` weighted by `isSevere`. **Highest-value item.** |
| **`WeatherLocationEntity`** | `SavedLocation` + `.currentDevice` (`Stores/SavedLocation.swift`) | Backed by `EntityStringQuery` so "Geelong" resolves. `LocationSelectionStore.saved` is a ready-made `suggestedEntities()`. |
| **`DailyForecastEntity`** | `DailyForecastDay` | `extendedText` is already prose — ideal `contentDescription`. |
| *(optional)* `WeatherStationEntity` | `WeatherStation` | Only if station-level queries matter. |

### Intents

| Intent | Shape |
|---|---|
| `GetCurrentConditionsIntent` | plain `AppIntent`, returns `.result(dialog:view:)` |
| `GetForecastIntent` | plain `AppIntent`, `@Parameter` day offset with a default |
| `GetWarningsIntent` | plain `AppIntent`, returns `[WeatherWarningEntity]` |
| `OpenRadarIntent` | `@AppIntent(schema: .system.open)` |
| `SearchWeatherIntent` | `@AppIntent(schema: .system.search)`, conforms `ShowInAppSearchResultsIntent` |

Register via an `AppShortcutsProvider`. Every phrase must contain `\(.applicationName)`.

### Onscreen context — note this is iOS 18.4, not 27

Verified in the `_AppIntents_SwiftUI` cross-import overlay (available when importing both SwiftUI and AppIntents):

```swift
@available(iOS 18.4, *)
extension View {
    func appEntityIdentifier(_ identifier: EntityIdentifier?) -> some View
    func appEntityIdentifier<I: Hashable>(forSelectionType: I.Type,
                                          identifier: @escaping @Sendable (I) -> EntityIdentifier?) -> some View
    func appEntityUIElements(_ provider: @escaping @MainActor (AppEntityUIElementsContext) -> [AppEntityUIElement]) -> some View
}
```

Tag `WarningsTabView` and `WeatherView` so "what does *this* warning mean?" resolves against what is on screen. Cheap, and it does not need iOS 27.

---

## 7. Three things that will bite

### 7.1 No App Group — fix this first
`grep -c application-groups` = 0. Both `LocationSelectionStore` and `WeatherStationStore` write to `UserDefaults.standard`.

In-app intents work fine. But the moment a widget or AppIntents extension is added — which is what lets intents run **without launching the app**, the whole point for Siri — those stores become invisible to it. Cheap now, invasive later.

### 7.2 Keep `ClaudeService` out of `perform()`
A network round-trip to `api.anthropic.com` against a user-supplied key is the wrong latency budget for a Siri response, and strands any user who hasn't entered a key in Settings. `AppleIntelligenceService` (on-device `LanguageModelSession`) is acceptable inside an intent; the Claude path is not.

### 7.3 Sendability
`WeatherService` is a `final class` singleton with mutable cache state (`Services/WeatherService.swift:32`, `DrivingWeatherCacheEntry` at `:45`). Intents are `Sendable` and run off the main actor. Expect to convert it to an `actor` or isolate the cache.

Related: `SWIFT_VERSION = 5.0` — worth confirming the concurrency checking level before adding `Sendable` conformances at scale.

---

## 8. Recommended order of work

1. **App Group + `WeatherWarningEntity` as `IndexedEntity`** — highest leverage. Semantic Spotlight search is the one mechanism that does not require a schema domain we don't have.
2. **`WeatherLocationEntity` + the three read intents + `AppShortcutsProvider`.**
3. **Onscreen context tagging** (`appEntityIdentifier`) on `WarningsTabView` / `WeatherView`.
4. **AppIntents extension target** so intents answer without a cold app launch.
5. *(Later)* `IndexedEntityQuery` for system-driven reindex; `LongRunningIntent` for the bundle fetch.

---

## 9. Realistic ceiling

Without a weather schema domain, **Siri AI will not route generic weather questions to papaWeather.** Apple's Weather app owns those.

What papaWeather can realistically own is **BOM-specific content Apple does not have** — warnings, nearest-station observations, radar — reached either by the user naming the app, or by semantic match on indexed warning text.

Set expectations accordingly: this is a discoverability and depth play, not a "replace the Weather app in Siri" play.

---

## Sources

- `iPhoneOS27.0.sdk/System/Library/Frameworks/AppIntents.framework/.../AppIntents.swiftinterface`
- `iPhoneOS27.0.sdk/System/Library/Frameworks/_AppIntents_SwiftUI.framework/.../_AppIntents_SwiftUI.swiftinterface`
- https://developer.apple.com/documentation/appintents/apple-intelligence-and-siri-ai
- https://developer.apple.com/documentation/appintents/app-schema-domains
- https://developer.apple.com/documentation/appintents/making-app-entities-available-in-spotlight
- https://developer.apple.com/documentation/appintents/providing-contextual-cues-to-apple-intelligence-and-siri
