import Foundation
import SwiftUI

// MARK: - Meal

enum MealType: String, Codable, CaseIterable {
    case breakfast = "Breakfast"
    case lunch = "Lunch"
    case dinner = "Dinner"
    case custom = "Custom"

    var icon: String {
        switch self {
        case .breakfast: return "sun.rise.fill"
        case .lunch: return "sun.max.fill"
        case .dinner: return "moon.stars.fill"
        case .custom: return "fork.knife.circle.fill"
        }
    }

    static var standardCases: [MealType] { [.breakfast, .lunch, .dinner] }
}

struct MealRecord: Identifiable, Codable {
    var id: UUID = UUID()
    var date: Date
    var type: MealType
    var customName: String?        // user-defined name for .custom meals
    var imageData: Data?
    var calories: Double?          // kcal, from AI or manual
    var aiDescription: String?
    var isAnalyzing: Bool = false

    var displayName: String { customName ?? type.rawValue }

    var dateKey: String {
        DateFormatter.dayKey.string(from: date)
    }
}

// MARK: - Weight

struct WeightRecord: Identifiable, Codable {
    var id: UUID = UUID()
    var date: Date
    var kg: Double

    var dateKey: String {
        DateFormatter.dayKey.string(from: date)
    }
}

// MARK: - Daily Energy (from HealthKit)

struct DailyEnergy: Codable {
    var date: Date
    var restingKcal: Double   // BMR / resting energy
    var activeKcal: Double    // active energy burned
    var sleepHours: Double    // sleep duration in hours

    var totalBurned: Double { restingKcal + activeKcal }

    var dateKey: String {
        DateFormatter.dayKey.string(from: date)
    }
}

// MARK: - Daily Summary (composite)

struct DailySummary {
    var date: Date
    var energy: DailyEnergy?
    var meals: [MealRecord]
    var weight: WeightRecord?

    var totalIntake: Double {
        meals.compactMap(\.calories).reduce(0, +)
    }

    var totalBurned: Double {
        energy?.totalBurned ?? 0
    }

    var netEnergy: Double {
        totalIntake - totalBurned
    }
}

// MARK: - Report

struct Report: Identifiable, Codable {
    var id: UUID = UUID()
    var createdAt: Date
    var type: ReportType
    var content: String

    enum ReportType: String, Codable {
        case daily = "Daily"
        case weekly = "Weekly"
    }
}

// MARK: - AI Model Config

enum AIProvider: String, Codable, CaseIterable {
    case anthropic = "Anthropic"
    case openaiCompatible = "OpenAI Compatible"

    var defaultURL: String {
        switch self {
        case .anthropic: return "https://api.anthropic.com/v1/messages"
        case .openaiCompatible: return "https://dashscope.aliyuncs.com/compatible-mode/v1/chat/completions"
        }
    }

    var apiKeyPlaceholder: String {
        switch self {
        case .anthropic: return "sk-ant-..."
        case .openaiCompatible: return "sk-..."
        }
    }
}

struct AIModelConfig: Identifiable, Codable {
    var id: UUID = UUID()
    var name: String
    var provider: AIProvider
    var apiURL: String
    var apiKey: String
    var modelID: String
    var supportsVision: Bool

    static func defaultAnthropic(apiKey: String = "") -> AIModelConfig {
        AIModelConfig(
            name: "Claude Opus 4.6",
            provider: .anthropic,
            apiURL: "https://api.anthropic.com/v1/messages",
            apiKey: apiKey,
            modelID: "claude-opus-4-6",
            supportsVision: true
        )
    }
}

// MARK: - DateFormatter helpers

extension DateFormatter {
    static let dayKey: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    static let display: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .none
        return f
    }()

    static let displayTime: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .none
        f.timeStyle = .short
        return f
    }()
}
