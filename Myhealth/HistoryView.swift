import SwiftUI
import Charts

struct HistoryView: View {
    @StateObject private var store = DataStore.shared
    @State private var selectedRange: ChartRange = .week

    enum ChartRange: String, CaseIterable {
        case week = "Week"
        case month = "Month"
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    Picker("Range", selection: $selectedRange) {
                        ForEach(ChartRange.allCases, id: \.self) { r in
                            Text(r.rawValue).tag(r)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)

                    // Energy Chart
                    EnergyChartSection(energies: filteredEnergies, intakeData: filteredIntakeData, range: selectedRange)
                        .padding(.horizontal)

                    // Weight Chart
                    WeightChartSection(weights: filteredWeights, range: selectedRange)
                        .padding(.horizontal)

                    // Sleep Chart
                    SleepChartSection(energies: filteredEnergies, range: selectedRange)
                        .padding(.horizontal)

                    Spacer(minLength: 20)
                }
                .padding(.top, 12)
            }
            .navigationTitle("History")
            .navigationBarTitleDisplayMode(.large)
        }
    }

    private var days: Int { selectedRange == .week ? 7 : 30 }

    private var filteredEnergies: [DailyEnergy] {
        store.recentEnergies(days: days)
    }

    private var filteredWeights: [WeightRecord] {
        let cutoff = Calendar.current.date(byAdding: .day, value: -days, to: Date())!
        return store.weights.filter { $0.date >= cutoff }.sorted { $0.date < $1.date }
    }

    private var filteredIntakeData: [(date: Date, kcal: Double)] {
        let cutoff = Calendar.current.date(byAdding: .day, value: -days, to: Date())!
        let calendar = Calendar.current

        // Group meals by day
        let grouped = Dictionary(grouping: store.meals.filter { $0.date >= cutoff }) { meal in
            calendar.startOfDay(for: meal.date)
        }
        return grouped.map { (date, meals) in
            (date: date, kcal: meals.compactMap(\.calories).reduce(0, +))
        }.sorted { $0.date < $1.date }
    }
}

// MARK: - Energy Chart

struct EnergyChartSection: View {
    let energies: [DailyEnergy]
    let intakeData: [(date: Date, kcal: Double)]
    let range: HistoryView.ChartRange

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Energy (kcal)")
                .font(.headline)

            if energies.isEmpty {
                EmptyChartPlaceholder(message: "No energy data yet")
            } else {
                Chart {
                    ForEach(energies, id: \.dateKey) { e in
                        BarMark(
                            x: .value("Date", e.date, unit: .day),
                            y: .value("Burned", e.totalBurned)
                        )
                        .foregroundStyle(Color.red.opacity(0.7))
                        .annotation(position: .top) { EmptyView() }
                    }
                    ForEach(intakeData, id: \.date) { entry in
                        LineMark(
                            x: .value("Date", entry.date, unit: .day),
                            y: .value("Intake", entry.kcal)
                        )
                        .foregroundStyle(.orange)
                        .lineStyle(StrokeStyle(lineWidth: 2))
                        PointMark(
                            x: .value("Date", entry.date, unit: .day),
                            y: .value("Intake", entry.kcal)
                        )
                        .foregroundStyle(.orange)
                    }
                }
                .frame(height: 200)
                .chartXAxis {
                    AxisMarks(values: .stride(by: .day, count: range == .week ? 1 : 5)) {
                        AxisGridLine()
                        AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                    }
                }

                // Legend
                HStack(spacing: 16) {
                    LegendItem(color: .red.opacity(0.7), label: "Burned")
                    LegendItem(color: .orange, label: "Intake")
                }
                .font(.caption)
            }
        }
        .padding(16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
    }
}

// MARK: - Weight Chart

struct WeightChartSection: View {
    let weights: [WeightRecord]
    let range: HistoryView.ChartRange

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Weight (kg)")
                .font(.headline)

            if weights.isEmpty {
                EmptyChartPlaceholder(message: "No weight data yet")
            } else {
                Chart(weights) { w in
                    LineMark(
                        x: .value("Date", w.date, unit: .day),
                        y: .value("Weight", w.kg)
                    )
                    .foregroundStyle(.green)
                    .lineStyle(StrokeStyle(lineWidth: 2))
                    PointMark(
                        x: .value("Date", w.date, unit: .day),
                        y: .value("Weight", w.kg)
                    )
                    .foregroundStyle(.green)
                    .annotation(position: .top) {
                        Text(String(format: "%.1f", w.kg))
                            .font(.system(size: 9))
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(height: 160)
                .chartXAxis {
                    AxisMarks(values: .stride(by: .day, count: range == .week ? 1 : 5)) {
                        AxisGridLine()
                        AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                    }
                }
                .chartYAxis {
                    AxisMarks {
                        AxisGridLine()
                        AxisValueLabel()
                    }
                }
            }
        }
        .padding(16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
    }
}

// MARK: - Sleep Chart

struct SleepChartSection: View {
    let energies: [DailyEnergy]
    let range: HistoryView.ChartRange

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Sleep (hours)")
                .font(.headline)

            if energies.isEmpty {
                EmptyChartPlaceholder(message: "No sleep data yet")
            } else {
                Chart(energies, id: \.dateKey) { e in
                    BarMark(
                        x: .value("Date", e.date, unit: .day),
                        y: .value("Sleep", e.sleepHours)
                    )
                    .foregroundStyle(
                        e.sleepHours >= 7 ? Color.indigo : Color.indigo.opacity(0.4)
                    )
                    .cornerRadius(4)
                }
                .frame(height: 160)
                .chartXAxis {
                    AxisMarks(values: .stride(by: .day, count: range == .week ? 1 : 5)) {
                        AxisGridLine()
                        AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                    }
                }
                .chartYAxis {
                    AxisMarks {
                        AxisGridLine()
                        AxisValueLabel()
                    }
                }

                // Reference line annotation
                HStack {
                    Rectangle()
                        .fill(Color.indigo)
                        .frame(width: 8, height: 8)
                    Text("≥7h recommended")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
    }
}

// MARK: - Helpers

struct EmptyChartPlaceholder: View {
    let message: String

    var body: some View {
        Text(message)
            .font(.subheadline)
            .foregroundStyle(.tertiary)
            .frame(maxWidth: .infinity)
            .frame(height: 120)
    }
}

struct LegendItem: View {
    let color: Color
    let label: String

    var body: some View {
        HStack(spacing: 4) {
            Circle().fill(color).frame(width: 8, height: 8)
            Text(label).foregroundStyle(.secondary)
        }
    }
}

#Preview {
    HistoryView()
}
