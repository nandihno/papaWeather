//
//  AppleIntelligenceService.swift
//  papaWeather
//
//  On-device AI analysis using Apple Foundation Models.
//

import Foundation
import FoundationModels

enum AppleIntelligenceError: LocalizedError {
    case unavailable(SystemLanguageModel.Availability.UnavailableReason)
    case unknown

    var errorDescription: String? {
        switch self {
        case .unavailable(.appleIntelligenceNotEnabled):
            return "Apple Intelligence is not enabled. Turn it on in Settings > Apple Intelligence & Siri."
        case .unavailable(.deviceNotEligible):
            return "This device does not support Apple Intelligence."
        case .unavailable(.modelNotReady):
            return "Apple Intelligence model is still downloading. Try again shortly."
        case .unavailable:
            return "Apple Intelligence is not available right now."
        case .unknown:
            return "An unknown error occurred."
        }
    }
}

enum AppleIntelligenceService {

    static func analyseWeather(
        forecastSummary: String,
        weeklyActivityPlan: WeeklyActivityPlan = WeeklyActivityPlan()
    ) async throws -> String {
        let spec = WeatherAnalysisSpecBuilder.make(
            forecastSummary: forecastSummary,
            weeklyActivityPlan: weeklyActivityPlan
        )
        return try await analyse(spec: spec)
    }

    static func analysePressure(observations: [WeatherObservation]) async throws -> String {
        switch SystemLanguageModel.default.availability {
        case .available:
            break
        case .unavailable(let reason):
            throw AppleIntelligenceError.unavailable(reason)
        }

        let chronological = observations.reversed()
        let readings = chronological.map {
            "\($0.localDateTime): \(String(format: "%.1f", $0.pressureMSL)) hPa"
        }.joined(separator: "\n")
        let hours = (observations.count / 2)

        let latest = observations.first?.pressureMSL ?? 1013.25
        let oldest = observations.last?.pressureMSL ?? latest
        let delta = latest - oldest
        let trend: String
        if delta > 0.5 {
            trend = "rising (+\(String(format: "%.1f", delta)) hPa over the period)"
        } else if delta < -0.5 {
            trend = "falling (\(String(format: "%.1f", delta)) hPa over the period)"
        } else {
            trend = "steady (±\(String(format: "%.1f", abs(delta))) hPa)"
        }

        let instructions = """
        You are a meteorologist interpreting barometric pressure from a personal weather station. \
        Given recent pressure readings and the trend, provide a plain-English weather outlook for \
        the next 3–6 hours. Standard sea-level pressure is 1013.25 hPa. \
        Rising pressure above 1013 hPa means improving, stable conditions. \
        Falling pressure below 1013 hPa means deteriorating conditions, possible rain or storms. \
        A rapid drop of more than 3 hPa/hour signals an imminent storm. \
        DO NOT exceed 35 words. DO NOT use bullet points, headings, or markdown — write one or two plain sentences only.
        """

        let prompt = """
        Barometric pressure readings over the last ~\(hours) hours (oldest to newest, one reading every 30 minutes):
        \(readings)

        Current: \(String(format: "%.1f", latest)) hPa. Trend over the last \(hours) hours: \(trend).

        What weather can I expect in the next 3–6 hours?
        """

        let session = LanguageModelSession(instructions: instructions)
        let response = try await session.respond(to: prompt)
        return String(response.content)
    }

    static func analyseHumidity(observations: [WeatherObservation]) async throws -> String {
        switch SystemLanguageModel.default.availability {
        case .available:
            break
        case .unavailable(let reason):
            throw AppleIntelligenceError.unavailable(reason)
        }

        let chronological = Array(observations.reversed())
        let hours = observations.count / 2

        let humidityValues = chronological.map { Double($0.relHumidity) }
        let latest  = humidityValues.last ?? 0
        let oldest  = humidityValues.first ?? latest
        let minVal  = humidityValues.min() ?? 0
        let maxVal  = humidityValues.max() ?? 0
        let average = humidityValues.reduce(0, +) / Double(humidityValues.count)
        let delta   = latest - oldest
        let trend: String
        if delta > 3      { trend = "rising (+\(Int(delta))% over the period)" }
        else if delta < -3 { trend = "falling (\(Int(delta))% over the period)" }
        else               { trend = "steady (±\(Int(abs(delta)))%)" }

        let currentAirTemp = observations.first.map { String(format: "%.1f", $0.airTemp) } ?? "unknown"

        let readings = chronological.map {
            "\($0.localDateTime): \($0.relHumidity)%"
        }.joined(separator: "\n")

        let instructions = """
        You are a health and environmental scientist interpreting OUTDOOR relative humidity data \
        from a personal weather station. These readings are from outside — NOT indoors. \
        DO NOT reference indoor activities such as cooking, showering, or drying clothes, as \
        these readings cannot reflect indoor conditions. Analyse the outdoor readings and give \
        a concise, plain-English assessment covering these areas as relevant:
        - HEALTH IMPACT OUTDOORS: Above 60% outdoor humidity allows mould spores and allergens \
          to thrive externally, worsening asthma and allergy symptoms for people spending time \
          outside. Below 30% dries nasal passages during outdoor exposure, increasing \
          respiratory vulnerability. High outdoor humidity combined with warm temperatures \
          significantly raises the risk of heat exhaustion and fatigue for anyone active outside.
        - OUTDOOR COMFORT: High outdoor humidity makes it feel hotter than it is and reduces \
          the body's ability to cool through sweating. Low humidity can feel parching and \
          increase dehydration risk during outdoor activity.
        - WEATHER SIGNAL: Rapidly rising outdoor humidity often precedes rain or fog. \
          Falling humidity after a peak can signal clearing conditions.
        - TEMPERATURE INTERACTION: Warm air holds more moisture outdoors; factor in the \
          current temperature when assessing how the humidity level feels and its health impact.
        DO NOT exceed 55 words. DO NOT use bullet points, headings, or markdown. \
        Write two or three plain sentences only. Be specific and actionable.
        """

        let prompt = """
        Relative humidity readings over the last ~\(hours) hours (oldest to newest, 30-minute intervals):
        \(readings)

        Summary: current \(Int(latest))%, min \(Int(minVal))%, max \(Int(maxVal))%, \
        average \(Int(average))%, trend \(trend).
        Current outdoor air temperature: \(currentAirTemp)°C.

        What health or comfort concerns should I be aware of when spending time outdoors, \
        and what does the humidity trend suggest about upcoming weather conditions?
        """

        let session = LanguageModelSession(instructions: instructions)
        let response = try await session.respond(to: prompt)
        return String(response.content)
    }

    private static func analyse(spec: ClaudeAnalysisSpec) async throws -> String {
        let session = LanguageModelSession(instructions: spec.systemPrompt)
        let response = try await session.respond(to: spec.userContent)
        return String(response.content)
    }
}
