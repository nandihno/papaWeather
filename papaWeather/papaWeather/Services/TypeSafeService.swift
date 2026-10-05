//
//  TypeSafeService.swift
//  papaWeather
//
//  Structured judgments from TypeSafe's Jev model, covering every section of
//  the AI weather briefing. Jev decides (typed choices, scores and
//  probabilities); the narrating LLM only explains what Jev decided.
//

import Foundation

// MARK: - Today

enum ClothingRecommendation: String, CaseIterable, Sendable {
    case light, layered, warm, waterproof

    var title: String {
        switch self {
        case .light: "Light"
        case .layered: "Layered"
        case .warm: "Warm"
        case .waterproof: "Waterproof layer"
        }
    }
}

enum OutdoorWindow: String, CaseIterable, Sendable {
    case earlyMorning, midMorning, midday, afternoon, evening, indoorsOnly

    var title: String {
        switch self {
        case .earlyMorning: "Early morning"
        case .midMorning: "Mid-morning"
        case .midday: "Midday"
        case .afternoon: "Afternoon"
        case .evening: "Evening"
        case .indoorsOnly: "Indoors only"
        }
    }
}

enum TipCategory: String, CaseIterable, Sendable {
    case hydration, sunProtection, rainGear, windCaution, frostCaution, layerUp, noSpecificTip

    var title: String {
        switch self {
        case .hydration: "Hydration"
        case .sunProtection: "Sun protection"
        case .rainGear: "Rain gear"
        case .windCaution: "Wind caution"
        case .frostCaution: "Frost caution"
        case .layerUp: "Layering"
        case .noSpecificTip: "No specific tip"
        }
    }
}

struct TodayVerdict: Sendable {
    let clothing: ClothingRecommendation
    let clothingConfidence: Double
    let umbrellaProbability: Double
    let uvProtectionProbability: Double
    let bestOutdoorWindow: OutdoorWindow
    let bestOutdoorWindowConfidence: Double
    let tipCategory: TipCategory
    let tipCategoryConfidence: Double
}

// MARK: - Commute

enum CommuteSeverity: Int, CaseIterable, Sendable {
    case noImpact = 0, minor, moderate, severe

    var title: String {
        switch self {
        case .noImpact: "No impact"
        case .minor: "Minor impact"
        case .moderate: "Moderate impact"
        case .severe: "Severe impact"
        }
    }
}

struct CommuteVerdict: Sendable {
    let morningSeverity: CommuteSeverity
    let morningScore: Double
    let morningConfidence: Double
    let eveningSeverity: CommuteSeverity
    let eveningScore: Double
    let eveningConfidence: Double
}

// MARK: - Week ahead

struct WeekDayFlag: Identifiable, Sendable {
    nonisolated static let notableThreshold = 0.55
    nonisolated static let concernThreshold = 0.6

    let day: WeeklyActivityDay?
    let dayTitle: String
    let date: String
    let notableProbability: Double
    /// Noul probabilities keyed by concern name ("heavyRain", "extremeHeat", "strongWind") that crossed the threshold.
    let concerns: [String]

    nonisolated var id: String { date }
    nonisolated var isNotable: Bool { notableProbability >= Self.notableThreshold }
}

// MARK: - Activities

enum ActivityRating: String, CaseIterable, Sendable {
    case ideal
    case suitable
    case caution
    case avoid

    var title: String { rawValue.capitalized }
}

struct ActivityVerdict: Identifiable, Sendable {
    /// Below this Choice confidence the verdict is reported as borderline.
    nonisolated static let lowConfidenceThreshold = 0.5
    /// A Noul at or above this probability counts as a real concern.
    nonisolated static let concernThreshold = 0.6

    let day: WeeklyActivityDay
    let date: String
    let activity: String
    let rating: ActivityRating
    let probabilities: [ActivityRating: Double]
    let confidence: Double
    /// Noul probabilities keyed by concern name ("rain", "heat", "wind", "uv").
    let concerns: [String: Double]

    nonisolated var id: String { day.id }
    nonisolated var isBorderline: Bool { confidence < Self.lowConfidenceThreshold }

    nonisolated var activeConcerns: [String] {
        concerns
            .filter { $0.value >= Self.concernThreshold }
            .sorted { $0.value > $1.value }
            .map(\.key)
    }
}

// MARK: - Whole-briefing judgment

/// Every Jev judgment behind one AI Weather Briefing request. Any piece may be
/// missing — each is judged independently and best-effort, so a failure in one
/// (or TypeSafe being off) never blocks the others.
struct BriefingJudgment: Sendable {
    let today: TodayVerdict?
    let commute: CommuteVerdict?
    let weekFlags: [WeekDayFlag]
    let activities: [ActivityVerdict]

    nonisolated static let empty = BriefingJudgment(today: nil, commute: nil, weekFlags: [], activities: [])

    nonisolated var isEmpty: Bool {
        today == nil && commute == nil && weekFlags.isEmpty && activities.isEmpty
    }
}

// MARK: - Prompt formatting

enum ActivityVerdictFormatter {
    /// Compact text block handed to the narrating LLM in place of the raw planner.
    nonisolated static func promptText(for verdicts: [ActivityVerdict]) -> String {
        let rows = verdicts.map { verdict -> String in
            var row = "\(verdict.day.title) (\(verdict.date)) — \"\(verdict.activity)\": \(verdict.rating.title)"
            row += String(format: " (confidence %.2f)", verdict.confidence)
            if verdict.isBorderline {
                row += ", borderline call"
            }
            let concerns = verdict.activeConcerns
            if !concerns.isEmpty {
                row += "; concerns: \(concerns.joined(separator: ", "))"
            }
            return row
        }
        .joined(separator: "\n")

        return """
        ACTIVITIES judgment (ratings from best to worst: ideal, suitable, caution, avoid):
        \(rows)
        """
    }
}

enum BriefingJudgmentFormatter {
    /// The full judgment block, for debug logging.
    nonisolated static func promptText(for judgment: BriefingJudgment) -> String {
        var blocks: [String] = []
        if let today = judgment.today { blocks.append(todayBlock(today)) }
        if let commute = judgment.commute { blocks.append(commuteBlock(commute)) }
        if !judgment.weekFlags.isEmpty { blocks.append(weekBlock(judgment.weekFlags)) }
        if !judgment.activities.isEmpty { blocks.append(ActivityVerdictFormatter.promptText(for: judgment.activities)) }
        return blocks.joined(separator: "\n\n")
    }

    nonisolated static func todayBlock(_ today: TodayVerdict) -> String {
        """
        TODAY judgment:
        Clothing: \(today.clothing.title) (confidence \(percent(today.clothingConfidence)))
        Umbrella: \(yesNo(today.umbrellaProbability)) (\(percent(today.umbrellaProbability)) likelihood recommended)
        Sun protection: \(yesNo(today.uvProtectionProbability)) (\(percent(today.uvProtectionProbability)) likelihood needed)
        Best outdoor window: \(today.bestOutdoorWindow.title) (confidence \(percent(today.bestOutdoorWindowConfidence)))
        Tip topic: \(today.tipCategory.title) (confidence \(percent(today.tipCategoryConfidence)))
        """
    }

    nonisolated static func commuteBlock(_ commute: CommuteVerdict) -> String {
        """
        COMMUTE judgment:
        Morning: \(commute.morningSeverity.title) (score \(formatScore(commute.morningScore)), confidence \(percent(commute.morningConfidence)))
        Evening: \(commute.eveningSeverity.title) (score \(formatScore(commute.eveningScore)), confidence \(percent(commute.eveningConfidence)))
        """
    }

    nonisolated static func weekBlock(_ flags: [WeekDayFlag]) -> String {
        let rows = flags.map { flag -> String in
            var row = "\(flag.dayTitle) (\(flag.date)): \(flag.isNotable ? "flagged" : "not flagged") (\(percent(flag.notableProbability)) likelihood)"
            if !flag.concerns.isEmpty { row += " — \(flag.concerns.joined(separator: ", "))" }
            return row
        }
        .joined(separator: "\n")
        return "WEEK AHEAD judgment:\n\(rows)"
    }

    private nonisolated static func percent(_ value: Double) -> String { "\(Int((value * 100).rounded()))%" }
    private nonisolated static func yesNo(_ probability: Double) -> String { probability >= 0.5 ? "yes" : "no" }
    private nonisolated static func formatScore(_ value: Double) -> String { String(format: "%.2f", value) }
}

// MARK: - Errors

enum TypeSafeError: LocalizedError {
    case httpStatus(Int)
    case missingAnswer(String)

    var errorDescription: String? {
        switch self {
        case .httpStatus(401): "TypeSafe rejected the API key."
        case .httpStatus(429): "TypeSafe rate limit reached. Try again shortly."
        case .httpStatus(let code): "TypeSafe request failed (HTTP \(code))."
        case .missingAnswer(let id): "TypeSafe response was missing the “\(id)” answer."
        }
    }
}

// MARK: - Wire types

/// Jev question, encoded as choice (criteria: object), noul (criteria: optional object)
/// or score (criteria: ordered array) per the TypeSafe API shape for each primitive.
private struct TSQuestion: Encodable {
    enum Criteria {
        case map([String: String])
        case list([String])
        case none
    }

    let type: String
    let instructions: String
    let criteria: Criteria

    private enum CodingKeys: String, CodingKey { case type, instructions, criteria }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(type, forKey: .type)
        try container.encode(instructions, forKey: .instructions)
        switch criteria {
        case .map(let dict): try container.encode(dict, forKey: .criteria)
        case .list(let array): try container.encode(array, forKey: .criteria)
        case .none: break
        }
    }

    static func choice(_ instructions: String, criteria: [String: String]) -> TSQuestion {
        TSQuestion(type: "choice", instructions: instructions, criteria: .map(criteria))
    }

    static func noul(_ instructions: String, criteria: [String: String]? = nil) -> TSQuestion {
        TSQuestion(type: "noul", instructions: instructions, criteria: criteria.map(Criteria.map) ?? .none)
    }

    static func score(_ instructions: String, levels: [String]) -> TSQuestion {
        TSQuestion(type: "score", instructions: instructions, criteria: .list(levels))
    }
}

private struct APIRequest<State: Encodable>: Encodable {
    let state: State
    let model = "jev-latest"
    let questions: [String: TSQuestion]
}

private struct SystemOneResponse: Decodable {
    let answers: [String: Answer]

    struct Answer: Decodable {
        let choice: String?
        let noul: Double?
        let score: Double?
        let probabilities: [String: Double]?
        let confidence: Double?
    }
}

private struct HourPayload: Encodable {
    let time: String
    let tempC: Int
    let feelsLikeC: Int
    let rainChancePercent: Int
    let windKmh: Int
    let gustKmh: Int
    let humidityPercent: Int
    let conditions: String
}

private struct DayForecastPayload: Encodable {
    let summary: String?
    let detail: String?
    let tempMinC: Int?
    let tempMaxC: Int?
    let rainChancePercent: Int?
    let rainAmountMm: String?
    let uvCategory: String?
    let fireDanger: String?
    let hourly: [HourPayload]
}

private struct ActivityState: Encodable {
    let day: String
    let date: String
    let today: String
    let daysFromToday: Int
    let activity: String
    let forecast: DayForecastPayload
}

private struct TodayState: Encodable {
    let day: String
    let date: String
    let today: String
    let forecast: DayForecastPayload
}

private struct WeekFlagState: Encodable {
    let day: String
    let date: String
    let today: String
    let daysFromToday: Int
    let forecast: DayForecastPayload
}

// MARK: - Service

enum TypeSafeService {
    private static let endpoint = URL(string: "https://api.typesafe.ai/v1/systemone")!
    private static let suitabilityID = "suitability"

    private static let concernQuestions: [(id: String, instructions: String)] = [
        ("rain", "Is rain likely to noticeably affect `activity` at the time of day it would happen, given `forecast`?"),
        ("heat", "Is heat (or a high feels-like temperature) likely to make `activity` uncomfortable or unsafe, given `forecast`?"),
        ("wind", "Is wind or gusting likely to make `activity` unpleasant or unsafe, given `forecast`?"),
        ("uv", "Does `forecast` indicate UV exposure high enough that sun protection is needed for `activity`?")
    ]

    // MARK: Public entry point

    /// Judges every section of the briefing in parallel: today, commute, which days this
    /// week deserve flagging, and every planner day with an activity. Every piece is
    /// best-effort — a failed or unavailable piece is simply left out, never thrown.
    static func judgeBriefing(
        forecast: DailyForecastInfo,
        hourly: HourlyForecastInfo?,
        plan: WeeklyActivityPlan,
        apiKey: String
    ) async -> BriefingJudgment {
        async let todayCommute = attempt(label: "today") {
            try await judgeTodayAndCommute(forecast: forecast, hourly: hourly, apiKey: apiKey)
        }
        async let weekFlags = judgeWeekAhead(forecast: forecast, hourly: hourly, apiKey: apiKey)
        async let activities = attempt(label: "activities") {
            try await judgeActivities(forecast: forecast, hourly: hourly, plan: plan, apiKey: apiKey)
        }

        let resolvedTodayCommute = await todayCommute
        let judgment = BriefingJudgment(
            today: resolvedTodayCommute?.today,
            commute: resolvedTodayCommute?.commute,
            weekFlags: await weekFlags,
            activities: await activities ?? []
        )

        #if DEBUG
        if !judgment.isEmpty {
            print("🧠 Jev briefing judgment:\n\(BriefingJudgmentFormatter.promptText(for: judgment))")
        }
        #endif
        return judgment
    }

    private static func attempt<T>(label: String, _ body: () async throws -> T) async -> T? {
        do { return try await body() }
        catch {
            print("TypeSafe \(label) judgment unavailable: \(error.localizedDescription)")
            return nil
        }
    }

    // MARK: Today + commute

    private struct TodayCommuteResult {
        let today: TodayVerdict
        let commute: CommuteVerdict
    }

    private static func judgeTodayAndCommute(
        forecast: DailyForecastInfo,
        hourly: HourlyForecastInfo?,
        apiKey: String
    ) async throws -> TodayCommuteResult {
        guard let firstDay = forecast.days.first else { throw TypeSafeError.missingAnswer("today") }

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        let parser = DateFormatter()
        parser.locale = Locale(identifier: "en_US_POSIX")
        parser.calendar = calendar
        parser.dateFormat = "yyyy-MM-dd"
        let date = parser.date(from: firstDay.date) ?? Date()

        let state = TodayState(
            day: "Today",
            date: firstDay.date,
            today: firstDay.date,
            forecast: forecastPayload(for: firstDay, hourly: hourly, date: date, calendar: calendar)
        )
        let request = APIRequest(state: state, questions: todayQuestions())
        let response = try await send(request, label: "today", apiKey: apiKey)

        guard let clothingChoice = response.answers["clothing"]?.choice,
              let clothing = ClothingRecommendation(rawValue: clothingChoice),
              let windowChoice = response.answers["bestOutdoorWindow"]?.choice,
              let window = OutdoorWindow(rawValue: windowChoice),
              let tipChoice = response.answers["tipCategory"]?.choice,
              let tip = TipCategory(rawValue: tipChoice),
              let umbrella = response.answers["umbrella"]?.noul,
              let uvProtection = response.answers["uvProtection"]?.noul,
              let morningScore = response.answers["commuteMorning"]?.score,
              let eveningScore = response.answers["commuteEvening"]?.score
        else { throw TypeSafeError.missingAnswer("today") }

        let today = TodayVerdict(
            clothing: clothing,
            clothingConfidence: response.answers["clothing"]?.confidence ?? 0,
            umbrellaProbability: umbrella,
            uvProtectionProbability: uvProtection,
            bestOutdoorWindow: window,
            bestOutdoorWindowConfidence: response.answers["bestOutdoorWindow"]?.confidence ?? 0,
            tipCategory: tip,
            tipCategoryConfidence: response.answers["tipCategory"]?.confidence ?? 0
        )
        let commute = CommuteVerdict(
            morningSeverity: commuteSeverity(for: morningScore),
            morningScore: morningScore,
            morningConfidence: response.answers["commuteMorning"]?.confidence ?? 0,
            eveningSeverity: commuteSeverity(for: eveningScore),
            eveningScore: eveningScore,
            eveningConfidence: response.answers["commuteEvening"]?.confidence ?? 0
        )
        return TodayCommuteResult(today: today, commute: commute)
    }

    private static func commuteSeverity(for score: Double) -> CommuteSeverity {
        let clamped = min(max(Int(score.rounded()), 0), CommuteSeverity.allCases.count - 1)
        return CommuteSeverity(rawValue: clamped) ?? .noImpact
    }

    private static let commuteLevels = [
        "No meaningful impact.",
        "Minor impact — a little rain or wind, nothing to plan around.",
        "Moderate impact — worth allowing extra time or bringing gear.",
        "Severe impact — conditions could disrupt or delay the commute."
    ]

    private static func todayQuestions() -> [String: TSQuestion] {
        [
            "clothing": .choice(
                """
                What clothing is most appropriate for being outdoors today, given `forecast`? Use \
                `forecast.detail` for nuance like frost or wind chill, and `forecast.hourly` for how \
                conditions change through the day.
                """,
                criteria: [
                    ClothingRecommendation.light.rawValue: "Cool, light clothing is enough — no jacket or extra layers needed.",
                    ClothingRecommendation.layered.rawValue: "Temperature or conditions vary enough through the day that layers you can add or remove work best.",
                    ClothingRecommendation.warm.rawValue: "Cold conditions call for a warm jacket or coat.",
                    ClothingRecommendation.waterproof.rawValue: "Rain is likely enough that a waterproof layer is worth wearing, regardless of temperature."
                ]
            ),
            "umbrella": .noul(
                "Is it worth bringing an umbrella today, given `forecast`?",
                criteria: [
                    "true": "Rain likely enough to be caught without one.",
                    "false": "Rain unlikely, or light enough to not bother."
                ]
            ),
            "uvProtection": .noul(
                "Is sun protection (sunscreen, hat, sunglasses) worth using today if spending time outdoors, given `forecast.uvCategory`?"
            ),
            "bestOutdoorWindow": .choice(
                """
                Using `forecast.hourly`, what is the most comfortable window today for outdoor activity \
                or exercise, balancing temperature, UV and rain? Pick indoorsOnly only if the whole day \
                is unpleasant outdoors.
                """,
                criteria: [
                    OutdoorWindow.earlyMorning.rawValue: "Roughly the first couple of hours after sunrise.",
                    OutdoorWindow.midMorning.rawValue: "Mid-morning, before the midday peak.",
                    OutdoorWindow.midday.rawValue: "Around midday.",
                    OutdoorWindow.afternoon.rawValue: "Mid-to-late afternoon.",
                    OutdoorWindow.evening.rawValue: "Evening, as temperatures cool.",
                    OutdoorWindow.indoorsOnly.rawValue: "Conditions are unpleasant or unsafe outdoors all day."
                ]
            ),
            "commuteMorning": .score(
                "How much will weather affect a morning commute today (walking, cycling, driving or public transport), focused on roughly 7–9am in `forecast.hourly`?",
                levels: commuteLevels
            ),
            "commuteEvening": .score(
                "How much will weather affect an evening commute today, focused on roughly 4–6pm in `forecast.hourly`?",
                levels: commuteLevels
            ),
            "tipCategory": .choice(
                "What is the single most useful category of advice to give the user about today's weather, given `forecast`?",
                criteria: [
                    TipCategory.hydration.rawValue: "Heat or exertion conditions where drinking enough water matters most.",
                    TipCategory.sunProtection.rawValue: "Sunscreen, a hat or sunglasses matter most today.",
                    TipCategory.rainGear.rawValue: "Rain is the main thing to prepare for.",
                    TipCategory.windCaution.rawValue: "Wind or gusts are the main thing to be careful of.",
                    TipCategory.frostCaution.rawValue: "Frost or very cold conditions are the main thing to prepare for.",
                    TipCategory.layerUp.rawValue: "A wide temperature swing through the day is the main thing to plan for.",
                    TipCategory.noSpecificTip.rawValue: "Nothing stands out enough to need a specific tip."
                ]
            )
        ]
    }

    // MARK: Week ahead

    private static func judgeWeekAhead(
        forecast: DailyForecastInfo,
        hourly: HourlyForecastInfo?,
        apiKey: String
    ) async -> [WeekDayFlag] {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        let parser = DateFormatter()
        parser.locale = Locale(identifier: "en_US_POSIX")
        parser.calendar = calendar
        parser.dateFormat = "yyyy-MM-dd"
        let today = parser.string(from: Date())

        var flags: [WeekDayFlag] = []
        await withTaskGroup(of: WeekDayFlag?.self) { group in
            for forecastDay in forecast.days {
                group.addTask {
                    guard let date = parser.date(from: forecastDay.date) else { return nil }
                    let weekday = WeeklyActivityDay(calendarWeekday: calendar.component(.weekday, from: date))
                    let daysFromToday = calendar.dateComponents(
                        [.day],
                        from: calendar.startOfDay(for: Date()),
                        to: calendar.startOfDay(for: date)
                    ).day ?? 0

                    let state = WeekFlagState(
                        day: weekday?.title ?? forecastDay.date,
                        date: forecastDay.date,
                        today: today,
                        daysFromToday: daysFromToday,
                        forecast: forecastPayload(for: forecastDay, hourly: hourly, date: date, calendar: calendar)
                    )
                    let request = APIRequest(state: state, questions: weekFlagQuestions())

                    do {
                        let response = try await send(request, label: "week \(forecastDay.date)", apiKey: apiKey)
                        guard let notable = response.answers["notable"]?.noul else {
                            throw TypeSafeError.missingAnswer("notable")
                        }
                        var concerns: [String] = []
                        for id in ["heavyRain", "extremeHeat", "strongWind"] {
                            if let value = response.answers[id]?.noul, value >= WeekDayFlag.concernThreshold {
                                concerns.append(id)
                            }
                        }
                        return WeekDayFlag(
                            day: weekday,
                            dayTitle: weekday?.title ?? forecastDay.date,
                            date: forecastDay.date,
                            notableProbability: notable,
                            concerns: concerns
                        )
                    } catch {
                        print("TypeSafe week-ahead judgment unavailable for \(forecastDay.date): \(error.localizedDescription)")
                        return nil
                    }
                }
            }
            for await result in group {
                if let result { flags.append(result) }
            }
        }
        return flags.sorted { $0.date < $1.date }
    }

    private static func weekFlagQuestions() -> [String: TSQuestion] {
        [
            "notable": .noul(
                """
                Is this day significant enough that a weekly weather overview should call it out to the \
                user — due to notably high or low temperature, heavy rain, strong wind, or fire danger, \
                compared to an ordinary day? `daysFromToday` gives how far out this day is.
                """
            ),
            "heavyRain": .noul("Is heavy or prolonged rain likely on this day, given `forecast`?"),
            "extremeHeat": .noul("Is the temperature high enough to be a heat concern on this day, given `forecast`?"),
            "strongWind": .noul("Is wind or gusting strong enough to be worth a specific warning on this day, given `forecast`?")
        ]
    }

    // MARK: Activities

    private struct Job {
        let day: WeeklyActivityDay
        let state: ActivityState
    }

    /// Judges every planner day that has an activity. Days whose request fails are
    /// skipped; throws only when every request fails.
    private static func judgeActivities(
        forecast: DailyForecastInfo,
        hourly: HourlyForecastInfo?,
        plan: WeeklyActivityPlan,
        apiKey: String
    ) async throws -> [ActivityVerdict] {
        let jobs = activityJobs(forecast: forecast, hourly: hourly, plan: plan)
        guard !jobs.isEmpty else { return [] }

        var verdicts: [ActivityVerdict] = []
        var lastError: Error?

        await withTaskGroup(of: Result<ActivityVerdict, Error>.self) { group in
            for job in jobs {
                group.addTask {
                    do { return .success(try await judge(job, apiKey: apiKey)) }
                    catch { return .failure(error) }
                }
            }
            for await result in group {
                switch result {
                case .success(let verdict): verdicts.append(verdict)
                case .failure(let error): lastError = error
                }
            }
        }

        if verdicts.isEmpty, let lastError { throw lastError }
        return verdicts.sorted { $0.date < $1.date }
    }

    private static func activityJobs(
        forecast: DailyForecastInfo,
        hourly: HourlyForecastInfo?,
        plan: WeeklyActivityPlan
    ) -> [Job] {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current

        let parser = DateFormatter()
        parser.locale = Locale(identifier: "en_US_POSIX")
        parser.calendar = calendar
        parser.dateFormat = "yyyy-MM-dd"

        let today = parser.string(from: Date())

        return forecast.days.compactMap { forecastDay in
            guard let date = parser.date(from: forecastDay.date),
                  let weekday = WeeklyActivityDay(calendarWeekday: calendar.component(.weekday, from: date))
            else { return nil }

            let activity = plan.activity(for: weekday)
            guard !activity.isEmpty else { return nil }

            let state = ActivityState(
                day: weekday.title,
                date: forecastDay.date,
                today: today,
                daysFromToday: calendar.dateComponents(
                    [.day],
                    from: calendar.startOfDay(for: Date()),
                    to: calendar.startOfDay(for: date)
                ).day ?? 0,
                activity: activity,
                forecast: forecastPayload(for: forecastDay, hourly: hourly, date: date, calendar: calendar)
            )
            return Job(day: weekday, state: state)
        }
    }

    private static func activityQuestions() -> [String: TSQuestion] {
        var questions: [String: TSQuestion] = [
            suitabilityID: .choice(
                """
                Determine the most appropriate recommendation for doing `activity` on this day, \
                given `forecast` (`forecast.detail` is the forecaster's written outlook, including frost and wind). \
                `daysFromToday` is 0 for today. If the activity names a time of day, judge the `forecast.hourly` \
                entries around that time; otherwise judge the day as a whole. Consider temperature, \
                rain, wind, UV and general comfort. If the activity is entirely indoors, weather \
                does not matter and it is ideal.
                """,
                criteria: [
                    ActivityRating.ideal.rawValue: "Good conditions for the activity with no meaningful concerns.",
                    ActivityRating.suitable.rawValue: "Generally good conditions, with minor precautions.",
                    ActivityRating.caution.rawValue: "The activity is possible but conditions are noticeably less comfortable or need planning around.",
                    ActivityRating.avoid.rawValue: "Conditions make the activity inadvisable or unsafe."
                ]
            )
        ]
        for concern in concernQuestions {
            questions[concern.id] = .noul(concern.instructions)
        }
        return questions
    }

    private static func judge(_ job: Job, apiKey: String) async throws -> ActivityVerdict {
        let request = APIRequest(state: job.state, questions: activityQuestions())
        let response = try await send(request, label: "\(job.state.day) — \(job.state.activity)", apiKey: apiKey)

        guard let answer = response.answers[suitabilityID],
              let choice = answer.choice,
              let rating = ActivityRating(rawValue: choice)
        else { throw TypeSafeError.missingAnswer(suitabilityID) }

        var probabilities: [ActivityRating: Double] = [:]
        for (key, value) in answer.probabilities ?? [:] {
            if let rating = ActivityRating(rawValue: key) { probabilities[rating] = value }
        }

        var concerns: [String: Double] = [:]
        for concern in concernQuestions {
            if let value = response.answers[concern.id]?.noul { concerns[concern.id] = value }
        }

        return ActivityVerdict(
            day: job.day,
            date: job.state.date,
            activity: job.state.activity,
            rating: rating,
            probabilities: probabilities,
            confidence: answer.confidence ?? 0,
            concerns: concerns
        )
    }

    // MARK: Shared forecast payload

    private static func forecastPayload(
        for day: DailyForecastDay,
        hourly: HourlyForecastInfo?,
        date: Date,
        calendar: Calendar
    ) -> DayForecastPayload {
        let hours = (hourly?.hours ?? [])
            .filter { calendar.isDate($0.rawDate, inSameDayAs: date) }
            .map {
                HourPayload(
                    time: $0.time,
                    tempC: $0.temp,
                    feelsLikeC: $0.feelsLike,
                    rainChancePercent: $0.rainChance,
                    windKmh: $0.windSpeedKmh,
                    gustKmh: $0.gustSpeedKmh,
                    humidityPercent: $0.relativeHumidity,
                    conditions: $0.iconDescriptor
                )
            }

        return DayForecastPayload(
            summary: day.shortText,
            detail: day.extendedText?.trimmingCharacters(in: .whitespacesAndNewlines),
            tempMinC: day.tempMin,
            tempMaxC: day.tempMax,
            rainChancePercent: day.rainChancePercent,
            rainAmountMm: rainAmount(for: day),
            uvCategory: day.uvCategory,
            fireDanger: day.fireDanger,
            hourly: hours
        )
    }

    private static func rainAmount(for day: DailyForecastDay) -> String? {
        switch (day.rainAmountMinMm, day.rainAmountMaxMm) {
        case let (min?, max?): "\(min)-\(max)"
        case let (min?, nil): "\(min)"
        default: nil
        }
    }

    // MARK: Networking

    private static func send<State>(
        _ payload: APIRequest<State>,
        label: String,
        apiKey: String
    ) async throws -> SystemOneResponse {
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONEncoder().encode(payload)

        var attempt = 0
        while true {
            let (data, response) = try await URLSession.shared.data(for: request)
            let status = (response as? HTTPURLResponse)?.statusCode ?? 200

            switch status {
            case 200:
                #if DEBUG
                let body = String(data: data, encoding: .utf8) ?? "<non-UTF8 body>"
                print("🧠 Jev response (\(label)):\n\(body)")
                #endif
                return try JSONDecoder().decode(SystemOneResponse.self, from: data)
            case 429, 529:
                guard attempt < 2 else { throw TypeSafeError.httpStatus(status) }
                attempt += 1
                try await Task.sleep(for: .milliseconds(400 * (1 << attempt)))
            default:
                throw TypeSafeError.httpStatus(status)
            }
        }
    }
}

// MARK: - Weekday mapping

extension WeeklyActivityDay {
    /// Maps `Calendar` weekday numbers (1 = Sunday … 7 = Saturday).
    nonisolated init?(calendarWeekday: Int) {
        switch calendarWeekday {
        case 1: self = .sunday
        case 2: self = .monday
        case 3: self = .tuesday
        case 4: self = .wednesday
        case 5: self = .thursday
        case 6: self = .friday
        case 7: self = .saturday
        default: return nil
        }
    }
}
