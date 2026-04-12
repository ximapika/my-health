import Foundation
import Combine

class DataStore: ObservableObject {
    static let shared = DataStore()

    // MARK: - Keys

    private enum Key {
        static let meals = "meals_v1"
        static let weights = "weights_v1"
        static let plannerItems = "planner_items_v1"
        static let energies = "energies_v1"
        static let reports = "reports_v1"
        static let modelConfigs = "ai_model_configs_v1"
        static let selectedModelID = "ai_selected_model_id"
        static let legacyAPIKey = "anthropic_api_key"
    }

    // MARK: - Published

    @Published var meals: [MealRecord] = []
    @Published var weights: [WeightRecord] = []
    @Published var plannerItems: [PlannerItem] = []
    @Published var energies: [DailyEnergy] = []
    @Published var reports: [Report] = []
    @Published var modelConfigs: [AIModelConfig] = []

    var selectedModelID: String? {
        get { UserDefaults.standard.string(forKey: Key.selectedModelID) }
        set { UserDefaults.standard.set(newValue, forKey: Key.selectedModelID) }
    }

    var selectedModel: AIModelConfig? {
        if let idStr = selectedModelID, let uuid = UUID(uuidString: idStr) {
            return modelConfigs.first { $0.id == uuid }
        }
        return modelConfigs.first
    }

    // Legacy compatibility
    var apiKey: String { selectedModel?.apiKey ?? "" }

    private init() {
        load()
    }

    // MARK: - Load

    private func load() {
        meals = decode([MealRecord].self, key: Key.meals) ?? []
        weights = decode([WeightRecord].self, key: Key.weights) ?? []
        plannerItems = decode([PlannerItem].self, key: Key.plannerItems) ?? []
        energies = decode([DailyEnergy].self, key: Key.energies) ?? []
        reports = decode([Report].self, key: Key.reports) ?? []
        modelConfigs = decode([AIModelConfig].self, key: Key.modelConfigs) ?? []
        sortPlannerItems()

        // Migrate legacy Anthropic API key on first launch
        if modelConfigs.isEmpty {
            let legacyKey = UserDefaults.standard.string(forKey: Key.legacyAPIKey) ?? ""
            modelConfigs = [AIModelConfig.defaultAnthropic(apiKey: legacyKey)]
            save(modelConfigs, key: Key.modelConfigs)
        }
    }

    // MARK: - Model Configs

    func upsertModelConfig(_ config: AIModelConfig) {
        if let idx = modelConfigs.firstIndex(where: { $0.id == config.id }) {
            modelConfigs[idx] = config
        } else {
            modelConfigs.append(config)
        }
        save(modelConfigs, key: Key.modelConfigs)
    }

    func deleteModelConfig(id: UUID) {
        modelConfigs.removeAll { $0.id == id }
        if selectedModelID == id.uuidString {
            selectedModelID = modelConfigs.first?.id.uuidString
        }
        save(modelConfigs, key: Key.modelConfigs)
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

    // MARK: - Planner

    func upsertPlannerItem(_ item: PlannerItem) {
        if let idx = plannerItems.firstIndex(where: { $0.id == item.id }) {
            plannerItems[idx] = item
        } else {
            plannerItems.append(item)
        }
        persistPlannerItems()
    }

    func deletePlannerItem(id: UUID) {
        plannerItems.removeAll { $0.id == id }
        save(plannerItems, key: Key.plannerItems)
    }

    func togglePlannerItemCompletion(id: UUID) {
        guard let idx = plannerItems.firstIndex(where: { $0.id == id }) else { return }
        plannerItems[idx].isCompleted.toggle()
        plannerItems[idx].completedAt = plannerItems[idx].isCompleted ? Date() : nil
        persistPlannerItems()
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

    private func persistPlannerItems() {
        sortPlannerItems()
        save(plannerItems, key: Key.plannerItems)
    }

    private func sortPlannerItems() {
        plannerItems.sort { lhs, rhs in
            if lhs.isCompleted != rhs.isCompleted {
                return !lhs.isCompleted && rhs.isCompleted
            }
            if lhs.deadline != rhs.deadline {
                return lhs.deadline < rhs.deadline
            }
            return lhs.createdAt < rhs.createdAt
        }
    }
}
