import Foundation
import Combine
import HealthKit

@MainActor
class HealthKitManager: ObservableObject {
    static let shared = HealthKitManager()

    private let store = HKHealthStore()

    @Published var isAuthorized = false
    @Published var authError: String?

    private let readTypes: Set<HKObjectType> = {
        var types = Set<HKObjectType>()
        if let resting = HKQuantityType.quantityType(forIdentifier: .basalEnergyBurned) {
            types.insert(resting)
        }
        if let active = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned) {
            types.insert(active)
        }
        if let sleep = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) {
            types.insert(sleep)
        }
        return types
    }()

    func requestAuthorization() async {
        guard HKHealthStore.isHealthDataAvailable() else {
            authError = "Health data is not available on this device."
            return
        }
        do {
            try await store.requestAuthorization(toShare: [], read: readTypes)
            isAuthorized = true
        } catch {
            authError = error.localizedDescription
        }
    }

    // MARK: - Resting Energy (Basal)

    func fetchRestingEnergy(for date: Date) async -> Double {
        guard let type = HKQuantityType.quantityType(forIdentifier: .basalEnergyBurned) else { return 0 }
        return await fetchSum(type: type, unit: .kilocalorie(), for: date)
    }

    // MARK: - Active Energy

    func fetchActiveEnergy(for date: Date) async -> Double {
        guard let type = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned) else { return 0 }
        return await fetchSum(type: type, unit: .kilocalorie(), for: date)
    }

    // MARK: - Sleep

    func fetchSleepHours(for date: Date) async -> Double {
        guard let type = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else { return 0 }

        // Sleep window: previous noon to current noon
        let calendar = Calendar.current
        let noon = calendar.date(bySettingHour: 12, minute: 0, second: 0, of: date)!
        let previousNoon = calendar.date(byAdding: .day, value: -1, to: noon)!

        let predicate = HKQuery.predicateForSamples(withStart: previousNoon, end: noon)

        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: type,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: nil
            ) { _, samples, _ in
                guard let samples = samples as? [HKCategorySample] else {
                    continuation.resume(returning: 0)
                    return
                }

                let asleepValues: Set<Int> = [
                    HKCategoryValueSleepAnalysis.asleepCore.rawValue,
                    HKCategoryValueSleepAnalysis.asleepDeep.rawValue,
                    HKCategoryValueSleepAnalysis.asleepREM.rawValue,
                    HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue
                ]

                let totalSeconds = samples
                    .filter { asleepValues.contains($0.value) }
                    .reduce(0.0) { $0 + $1.endDate.timeIntervalSince($1.startDate) }

                continuation.resume(returning: totalSeconds / 3600)
            }
            store.execute(query)
        }
    }

    // MARK: - Fetch daily energy (composite)

    func fetchDailyEnergy(for date: Date) async -> DailyEnergy {
        async let resting = fetchRestingEnergy(for: date)
        async let active = fetchActiveEnergy(for: date)
        async let sleep = fetchSleepHours(for: date)

        return DailyEnergy(
            date: date,
            restingKcal: await resting,
            activeKcal: await active,
            sleepHours: await sleep
        )
    }

    // MARK: - Last 7 days

    func fetchWeeklyEnergy() async -> [DailyEnergy] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        var results: [DailyEnergy] = []

        for i in 0..<7 {
            if let day = calendar.date(byAdding: .day, value: -i, to: today) {
                let energy = await fetchDailyEnergy(for: day)
                results.append(energy)
            }
        }
        return results.reversed()
    }

    // MARK: - Private helpers

    private nonisolated func fetchSum(type: HKQuantityType, unit: HKUnit, for date: Date) async -> Double {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: date)
        let end = calendar.date(byAdding: .day, value: 1, to: start)!

        let predicate = HKQuery.predicateForSamples(withStart: start, end: end)

        return await withCheckedContinuation { continuation in
            let query = HKStatisticsQuery(
                quantityType: type,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum
            ) { _, result, _ in
                let value = result?.sumQuantity()?.doubleValue(for: unit) ?? 0
                continuation.resume(returning: value)
            }
            self.store.execute(query)
        }
    }
}
