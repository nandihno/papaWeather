//
//  ClaudeService.swift
//  papaWeather
//

import Foundation

// MARK: - AI Provider

enum AIProvider: String {
    case appleIntelligence
    case claude
}

// MARK: - Claude client

private enum ClaudeClient {
    private static let endpoint = URL(string: "https://api.anthropic.com/v1/messages")!

    static func send(
        _ payload: ClaudeMessageRequest,
        apiKey: String
    ) async throws -> ClaudeMessageResponse {
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.httpBody = try JSONEncoder().encode(payload)

        let (data, response) = try await URLSession.shared.data(for: request)

        if let http = response as? HTTPURLResponse, http.statusCode != 200 {
            if let wrapper = try? JSONDecoder().decode(ClaudeErrorResponse.self, from: data) {
                throw ClaudeAPIError.apiMessage(wrapper.error.message)
            }
            throw ClaudeAPIError.httpStatus(http.statusCode)
        }

        return try JSONDecoder().decode(ClaudeMessageResponse.self, from: data)
    }
}

// MARK: - Public service

enum ClaudeService {
    static func analyse(spec: ClaudeAnalysisSpec, apiKey: String) async throws -> String {
        let request = ClaudeMessageRequest(
            model: spec.model,
            maxTokens: spec.maxTokens,
            system: spec.systemPrompt,
            messages: [.init(role: "user", content: spec.userContent)]
        )
        let response = try await ClaudeClient.send(request, apiKey: apiKey)
        return response.content.compactMap(\.text).first ?? "No analysis available"
    }

    static func analyseWeather(
        forecastSummary: String,
        weeklyActivityPlan: WeeklyActivityPlan = WeeklyActivityPlan(),
        apiKey: String
    ) async throws -> String {
        let spec = WeatherAnalysisSpecBuilder.make(
            forecastSummary: forecastSummary,
            weeklyActivityPlan: weeklyActivityPlan
        )
        return try await analyse(spec: spec, apiKey: apiKey)
    }
}

// MARK: - Analysis spec

struct ClaudeAnalysisSpec {
    var model: String = "claude-haiku-4-5"
    var maxTokens: Int = 1024
    var systemPrompt: String
    var userContent: String
}

enum WeatherAnalysisSpecBuilder {
    static func make(
        forecastSummary: String,
        weeklyActivityPlan: WeeklyActivityPlan = WeeklyActivityPlan()
    ) -> ClaudeAnalysisSpec {
        let now = Date()
        let dateFmt = DateFormatter()
        dateFmt.dateStyle = .full
        dateFmt.timeStyle = .short
        let dateTimeStr = dateFmt.string(from: now)

        let userContent = """
        Today's date and time: \(dateTimeStr)

        7-day forecast:
        \(forecastSummary)

        \(weeklyActivityPlan.promptText)
        """

        return ClaudeAnalysisSpec(
            systemPrompt: """
            You are a personal weather assistant, giving todays date with the following 7 day forecast.
            Your Task:
            Analyse this weather data and provide a brief, practical summary. Focus on:

            1. TODAY — What to wear, whether to bring an umbrella, UV protection needed, best time for outdoor activity or gym
            2. COMMUTE — Any weather impact on the morning or evening commute
            3. WEEK AHEAD — Flag any notable days (extreme heat, heavy rain, fire danger)
            4. ACTIVITIES — Use the user's weekly activity planner to advise which listed plans are weather-friendly, need timing changes, or should be reconsidered
            5. ONE SPECIFIC TIP — Something actionable based on the forecast

            RULES:
            - Be concise — max 150 words total
            - Use plain conversational English
            - No bullet points — write in short paragraphs
            - Don't just repeat the data — interpret it
            - Do not invent activities for blank planner days
            - If the planner has no entries, keep activity advice general and forecast-driven
            - If fire danger is Extreme or Catastrophic, always highlight this prominently
            - Temperatures in Celsius
            - Use a ## header for each section (e.g. ## Today, ## Commute, ## Week Ahead, ## Tip)
            """,
            userContent: userContent
        )
    }
}

// MARK: - Request/response models

struct ClaudeMessageRequest: Encodable {
    struct Message: Encodable {
        let role: String
        let content: String
    }

    let model: String
    let maxTokens: Int
    let system: String
    let messages: [Message]

    enum CodingKeys: String, CodingKey {
        case model
        case maxTokens = "max_tokens"
        case system
        case messages
    }
}

struct ClaudeMessageResponse: Decodable {
    struct ContentBlock: Decodable {
        let type: String
        let text: String?
    }
    let content: [ContentBlock]
}

private struct ClaudeErrorResponse: Decodable {
    struct APIError: Decodable {
        let type: String
        let message: String
    }
    let error: APIError
}

// MARK: - Error type

enum ClaudeAPIError: LocalizedError {
    case apiMessage(String)
    case httpStatus(Int)

    var errorDescription: String? {
        switch self {
        case .apiMessage(let msg): return msg
        case .httpStatus(let code): return "Request failed with status \(code)"
        }
    }
}
