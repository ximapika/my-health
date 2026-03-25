import Foundation
import UIKit

class AIService {
    static let shared = AIService()
    private init() {}

    // MARK: - Meal Analysis

    /// Analyze a meal photo and return estimated calories + description
    func analyzeMeal(image: UIImage, mealLabel: String) async throws -> (calories: Double, description: String) {
        let config = try activeConfig()
        guard config.supportsVision else {
            throw AIError.visionNotSupported(config.name)
        }

        let prompt = """
        This is a photo of my \(mealLabel.lowercased()).
        Please estimate the total calorie content (kcal) of all visible food items.
        Respond with a JSON object in this exact format:
        {"calories": <number>, "description": "<brief description of items and portions>"}
        Only respond with the JSON, no other text.
        """

        let requestBody = try buildVisionRequest(image: image, prompt: prompt, config: config)
        let responseText = try await sendRequest(body: requestBody, config: config)

        // Parse JSON response
        guard let data = responseText.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let calories = json["calories"] as? Double,
              let description = json["description"] as? String else {
            if let calories = extractCalories(from: responseText) {
                return (calories, responseText)
            }
            throw AIError.parseError(responseText)
        }

        return (calories, description)
    }

    // MARK: - Daily Report

    func generateDailyReport(summary: DailySummary) async throws -> String {
        let config = try activeConfig()

        let dateStr = DateFormatter.display.string(from: summary.date)
        let mealLines = summary.meals.map { m in
            "\(m.type.rawValue): \(m.aiDescription ?? "unknown") - \(m.calories.map { "\(Int($0)) kcal" } ?? "unknown")"
        }.joined(separator: "\n")

        let prompt = """
        Please generate a concise daily health summary for \(dateStr):

        Energy burned: \(Int(summary.totalBurned)) kcal (Resting: \(Int(summary.energy?.restingKcal ?? 0)), Active: \(Int(summary.energy?.activeKcal ?? 0)))
        Energy intake: \(Int(summary.totalIntake)) kcal
        Net energy balance: \(Int(summary.netEnergy)) kcal
        Sleep: \(String(format: "%.1f", summary.energy?.sleepHours ?? 0)) hours
        Weight: \(summary.weight.map { String(format: "%.1f kg", $0.kg) } ?? "not recorded")

        Meals:
        \(mealLines.isEmpty ? "No meals recorded" : mealLines)

        Write a friendly, motivating daily report (3-5 sentences) covering energy balance, sleep quality, and any notable observations. Be specific with the numbers.
        """

        return try await sendRequest(body: buildTextRequest(prompt: prompt, config: config), config: config)
    }

    // MARK: - Weekly Report

    func generateWeeklyReport(summaries: [DailySummary]) async throws -> String {
        let config = try activeConfig()

        let lines = summaries.map { s in
            let d = DateFormatter.display.string(from: s.date)
            return "\(d): burned \(Int(s.totalBurned)) kcal, intake \(Int(s.totalIntake)) kcal, net \(Int(s.netEnergy)) kcal, sleep \(String(format: "%.1f", s.energy?.sleepHours ?? 0))h, weight \(s.weight.map { String(format: "%.1f kg", $0.kg) } ?? "N/A")"
        }.joined(separator: "\n")

        let avgBurned = summaries.map(\.totalBurned).reduce(0, +) / Double(max(summaries.count, 1))
        let avgIntake = summaries.map(\.totalIntake).reduce(0, +) / Double(max(summaries.count, 1))
        let avgSleep = summaries.compactMap { $0.energy?.sleepHours }.reduce(0, +) / Double(max(summaries.count, 1))

        let prompt = """
        Weekly health summary data:

        \(lines)

        Weekly averages: burned \(Int(avgBurned)) kcal/day, intake \(Int(avgIntake)) kcal/day, sleep \(String(format: "%.1f", avgSleep)) hours/night.

        Please write a comprehensive weekly health report (5-8 sentences) covering: overall energy balance trend, sleep patterns, weight trend (if available), and personalized recommendations for next week.
        """

        return try await sendRequest(body: buildTextRequest(prompt: prompt, config: config), config: config)
    }

    // MARK: - Private Helpers

    private func activeConfig() throws -> AIModelConfig {
        guard let config = DataStore.shared.selectedModel, !config.apiKey.isEmpty else {
            throw AIError.noAPIKey
        }
        return config
    }

    private func buildVisionRequest(image: UIImage, prompt: String, config: AIModelConfig) throws -> [String: Any] {
        guard let imageData = image.jpegData(compressionQuality: 0.7) else {
            throw AIError.imageProcessingFailed
        }
        let base64Image = imageData.base64EncodedString()

        let content: [[String: Any]]
        switch config.provider {
        case .anthropic:
            content = [
                ["type": "image", "source": ["type": "base64", "media_type": "image/jpeg", "data": base64Image]],
                ["type": "text", "text": prompt]
            ]
        case .openaiCompatible:
            content = [
                ["type": "image_url", "image_url": ["url": "data:image/jpeg;base64,\(base64Image)"]],
                ["type": "text", "text": prompt]
            ]
        }

        return [
            "model": config.modelID,
            "max_tokens": 300,
            "messages": [["role": "user", "content": content]]
        ]
    }

    private func buildTextRequest(prompt: String, config: AIModelConfig) -> [String: Any] {
        [
            "model": config.modelID,
            "max_tokens": 600,
            "messages": [["role": "user", "content": prompt]]
        ]
    }

    private func sendRequest(body: [String: Any], config: AIModelConfig) async throws -> String {
        guard let url = URL(string: config.apiURL) else {
            throw AIError.networkError("Invalid URL: \(config.apiURL)")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        switch config.provider {
        case .anthropic:
            request.setValue(config.apiKey, forHTTPHeaderField: "x-api-key")
            request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        case .openaiCompatible:
            request.setValue("Bearer \(config.apiKey)", forHTTPHeaderField: "Authorization")
        }

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AIError.networkError("Invalid response")
        }
        guard httpResponse.statusCode == 200 else {
            let body = String(data: data, encoding: .utf8) ?? "unknown"
            throw AIError.networkError("HTTP \(httpResponse.statusCode): \(body)")
        }

        return try parseResponse(data: data, provider: config.provider)
    }

    private func parseResponse(data: Data, provider: AIProvider) throws -> String {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw AIError.parseError("Invalid JSON response")
        }

        switch provider {
        case .anthropic:
            guard let content = json["content"] as? [[String: Any]],
                  let first = content.first,
                  let text = first["text"] as? String else {
                throw AIError.parseError("Could not parse Anthropic response")
            }
            return text
        case .openaiCompatible:
            guard let choices = json["choices"] as? [[String: Any]],
                  let first = choices.first,
                  let message = first["message"] as? [String: Any],
                  let content = message["content"] as? String else {
                throw AIError.parseError("Could not parse OpenAI-compatible response")
            }
            return content
        }
    }

    private func extractCalories(from text: String) -> Double? {
        let pattern = #"(\d+(?:\.\d+)?)\s*(?:kcal|calories|cal)"#
        if let range = text.range(of: pattern, options: .regularExpression, locale: nil),
           let match = Double(text[range].components(separatedBy: CharacterSet.decimalDigits.inverted.union(CharacterSet(charactersIn: "."))).joined()) {
            return match
        }
        return nil
    }
}

// MARK: - Errors

enum AIError: LocalizedError {
    case noAPIKey
    case imageProcessingFailed
    case visionNotSupported(String)
    case networkError(String)
    case parseError(String)

    var errorDescription: String? {
        switch self {
        case .noAPIKey: return "Please add an API key in Settings → AI Models."
        case .imageProcessingFailed: return "Failed to process the image."
        case .visionNotSupported(let name): return "\"\(name)\" does not support image analysis. Select a vision-capable model in Settings."
        case .networkError(let msg): return "Network error: \(msg)"
        case .parseError(let msg): return "Could not parse AI response: \(msg)"
        }
    }
}
