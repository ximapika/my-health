import Foundation
import Combine

class DataStore: ObservableObject {
    static let shared = DataStore()

    // MARK: - Keys

    private enum Key {
        static let meals = "meals_v1"
        static let weights = "weights_v1"
        static let energies = "energies_v1"
        static let reports = "reports_v1"
        static let apiKey = "anthropic_api_key"
    }

    // MARK: - Published

    @Published var meals: [MealRecord] = []
    @Published var weights: [WeightRecord] = []
    @Published var energies: [DailyEnergy] = []
    @Published var reports: [Report] = []

    // API key stored in UserDefaults (for simplicity; Keychain preferred in production)
    var apiKey: String {
        get { UserDefaults.standard.string(forKey: Key.apiKey) ?? "" }
        set { UserDefaults.standard.set(newValue, forKey: Key.apiKey) }
    }

    private init() {
        load()
    }

    // MARK: - Load

    private func load() {
        meals = decode([MealRecord].self, key: Key.meals) ?? []
        weights = decode([WeightRecord].self, key: Key.weights) ?? []
        energies = decode([DailyEnergy].self, key: Key.energies) ?? []
        reports = decode([Report].self, key: Key.reports) ?? []
    }

    // MARK: - Meals

    func upsertMeal(_ meal: MealRecord) {
        if let idx = meals.firstIndex(where: { $0.id == meal.id }) {
            meals[idx] = meal
        } else {
            meals.append(meal)
        }
        save(meals, key: Key.meals)
    }

    func deleteMeal(id: UUID) {
        meals.removeAll { $0.id == id }
        save(meals, key: Key.meals)
    }

    func meals(for date: Date) -> [MealRecord] {
        let key = DateFormatter.dayKey.string(from: date)
        return meals.filter { $0.dateKey == key }
    }

    // MARK: - Weight

    func upsertWeight(_ record: WeightRecord) {
        if let idx = weights.firstIndex(where: { $0.dateKey == record.dateKey }) {
            weights[idx] = record
        } else {
            weights.append(record)
        }
        weights.sort { $0.date < $1.date }
        save(weights, key: Key.weights)
    }

    func weight(for date: Date) -> WeightRecord? {
        let key = DateFormatter.dayKey.string(from: date)
        return weights.last { $0.dateKey == key }
    }

    // MARK: - Energy (cache from HealthKit)

    func upsertEnergy(_ energy: DailyEnergy) {
        if let idx = energies.firstIndex(where: { $0.dateKey == energy.dateKey }) {
            energies[idx] = energy
        } else {
            energies.append(energy)
        }
        energies.sort { $0.date < $1.date }
        save(energies, key: Key.energies)
    }

    func energy(for date: Date) -> DailyEnergy? {
        let key = DateFormatter.dayKey.string(from: date)
        return energies.last { $0.dateKey == key }
    }

    func recentEnergies(days: Int) -> [DailyEnergy] {
        let sorted = energies.sorted { $0.date < $1.date }
        return Array(sorted.suffix(days))
    }

    // MARK: - Reports

    func addReport(_ report: Report) {
        reports.insert(report, at: 0)
        // Keep last 60 reports
        if reports.count > 60 { reports = Array(reports.prefix(60)) }
        save(reports, key: Key.reports)
    }

    // MARK: - Summary

    func dailySummary(for date: Date) -> DailySummary {
        DailySummary(
            date: date,
            energy: energy(for: date),
            meals: meals(for: date),
            weight: weight(for: date)
        )
    }

    // MARK: - Helpers

    private func save<T: Encodable>(_ value: T, key: String) {
        if let data = try? JSONEncoder().encode(value) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    private func decode<T: Decodable>(_ type: T.Type, key: String) -> T? {
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }
}
