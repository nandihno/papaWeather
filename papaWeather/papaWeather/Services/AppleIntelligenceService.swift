//
//  AppleIntelligenceService.swift
//  papaWeather
//
//  On-device AI analysis using Apple Foundation Models.
//

import Foundation
import FoundationModels

enum AppleIntelligenceService {

    static func analyseWeather(forecastSummary: String) async throws -> String {
        let spec = WeatherAnalysisSpecBuilder.make(forecastSummary: forecastSummary)
        return try await analyse(spec: spec)
    }

    private static func analyse(spec: ClaudeAnalysisSpec) async throws -> String {
        let session = LanguageModelSession(instructions: spec.systemPrompt)
        let response = try await session.respond(to: spec.userContent)
        return String(response.content)
    }
}
