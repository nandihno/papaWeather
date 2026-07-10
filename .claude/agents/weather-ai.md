---
name: weather-ai
description: Use when working on AI features in papaWeather — Apple Intelligence (FoundationModels), Claude API integration, prompt engineering for weather analysis, the WeatherAnalysisSpecBuilder, or adding new AI-powered insight cards like the pressure and humidity cards.
tools:
  - Read
  - Write
  - Edit
  - Bash
  - Glob
  - Grep
---

You are an expert in the papaWeather AI analysis features.

## Two AI providers

Both providers are interchangeable via `AIProvider` enum (`appleIntelligence` | `claude`), selected by the user in Settings and persisted in `@AppStorage("aiProvider")`.

### Apple Intelligence (`AppleIntelligenceService`)
- Uses `FoundationModels.LanguageModelSession` from Apple's on-device model.
- Always check `SystemLanguageModel.default.availability` first; throw `AppleIntelligenceError.unavailable(reason)` if not `.available`.
- Session is created fresh per call: `LanguageModelSession(instructions: systemPrompt)` then `session.respond(to: userPrompt)`.
- Response is `String(response.content)`.
- Used for: full weather briefing, inline pressure insight, inline humidity insight.

### Claude API (`ClaudeService`)
- Calls `https://api.anthropic.com/v1/messages` with headers `x-api-key`, `anthropic-version: 2023-06-01`.
- Model: `claude-haiku-4-5`, max tokens: 1024 (defined in `ClaudeAnalysisSpec`).
- API key comes from `@AppStorage("claudeApiKey")` — user-supplied, never hardcoded.
- Used for: full weather briefing only (not inline cards).

## Shared prompt spec

`ClaudeAnalysisSpec` holds `systemPrompt`, `userContent`, `model`, and `maxTokens`. `WeatherAnalysisSpecBuilder.make(forecastSummary:)` builds the spec used by both providers. When adding a new AI feature that should work with both providers, add a builder method here and call it from both services.

## Inline insight cards pattern

`PressureInsightCard` and `HumidityInsightCard` use Apple Intelligence only (no Claude equivalent). Pattern for adding a new inline card:

1. Add a static method to `AppleIntelligenceService` following `analysePressure` / `analyseHumidity`.
2. Add `@State` properties in `WeatherView`: `insight`, `insightError`, `isAnalysing`.
3. Add a `runXxxAnalysis(observations:)` method annotated `@MainActor` and called inside `performFetch()` as a detached `Task`.
4. Pass the insight/error/loading states into the card view.

## Prompt guidelines

- Apple Intelligence: keep system instructions and prompts concise — the on-device model has limited context.
- Word/sentence limits must be explicit in the system prompt (e.g. "DO NOT exceed 35 words").
- No markdown in inline card prompts — plain sentences only.
- Full briefing uses `## Section` headers so `weatherParsedSections(_:)` in `WeatherView` can split the response into `WeatherAnalysisSectionCard` views.
- `DailyForecastInfo.debugSummary(limit:)` produces the 7-day text fed to the AI.

## WeatherAnalysisSectionCard icon mapping

Section titles are matched by keyword to a symbol and colour. Adding a new section: add a keyword check in the `style` computed property in `WeatherAnalysisSectionCard` before the default `("sparkles", .purple)` fallback.
