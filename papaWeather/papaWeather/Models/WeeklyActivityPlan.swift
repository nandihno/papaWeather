//
//  WeeklyActivityPlan.swift
//  papaWeather
//

import Foundation

enum WeeklyActivityPlannerStorage {
    nonisolated static let monday = "weeklyActivityPlanner.monday"
    nonisolated static let tuesday = "weeklyActivityPlanner.tuesday"
    nonisolated static let wednesday = "weeklyActivityPlanner.wednesday"
    nonisolated static let thursday = "weeklyActivityPlanner.thursday"
    nonisolated static let friday = "weeklyActivityPlanner.friday"
    nonisolated static let saturday = "weeklyActivityPlanner.saturday"
    nonisolated static let sunday = "weeklyActivityPlanner.sunday"
}

enum WeeklyActivityDay: String, CaseIterable, Identifiable, Sendable {
    case monday
    case tuesday
    case wednesday
    case thursday
    case friday
    case saturday
    case sunday

    nonisolated var id: String { rawValue }

    nonisolated var title: String {
        switch self {
        case .monday: "Monday"
        case .tuesday: "Tuesday"
        case .wednesday: "Wednesday"
        case .thursday: "Thursday"
        case .friday: "Friday"
        case .saturday: "Saturday"
        case .sunday: "Sunday"
        }
    }

    nonisolated var storageKey: String {
        switch self {
        case .monday: WeeklyActivityPlannerStorage.monday
        case .tuesday: WeeklyActivityPlannerStorage.tuesday
        case .wednesday: WeeklyActivityPlannerStorage.wednesday
        case .thursday: WeeklyActivityPlannerStorage.thursday
        case .friday: WeeklyActivityPlannerStorage.friday
        case .saturday: WeeklyActivityPlannerStorage.saturday
        case .sunday: WeeklyActivityPlannerStorage.sunday
        }
    }
}

struct WeeklyActivityPlan: Sendable {
    nonisolated static let maxActivityLength = 250

    private let activities: [WeeklyActivityDay: String]

    nonisolated init(
        monday: String = "",
        tuesday: String = "",
        wednesday: String = "",
        thursday: String = "",
        friday: String = "",
        saturday: String = "",
        sunday: String = ""
    ) {
        activities = [
            .monday: monday,
            .tuesday: tuesday,
            .wednesday: wednesday,
            .thursday: thursday,
            .friday: friday,
            .saturday: saturday,
            .sunday: sunday
        ]
    }

    nonisolated func activity(for day: WeeklyActivityDay) -> String {
        String(
            activities[day, default: ""]
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .prefix(Self.maxActivityLength)
        )
    }

    nonisolated var hasActivities: Bool {
        WeeklyActivityDay.allCases.contains { !activity(for: $0).isEmpty }
    }

    nonisolated var promptText: String {
        guard hasActivities else {
            return """
            User weekly activity planner: no entries provided.
            Do not assume specific recurring chores or activities. Give only general weather guidance unless the forecast clearly warrants it.
            """
        }

        let rows = WeeklyActivityDay.allCases
            .map { day in "\(day.title): \(activity(for: day).isEmpty ? "No planned activity provided" : activity(for: day))" }
            .joined(separator: "\n")

        return """
        User weekly activity planner:
        \(rows)
        """
    }
}
