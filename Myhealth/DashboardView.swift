import SwiftUI

struct DashboardView: View {
    @StateObject private var store = DataStore.shared
    @StateObject private var healthKit = HealthKitManager.shared
    @State private var isRefreshing = false

    private var today: Date { Calendar.current.startOfDay(for: Date()) }
    private var summary: DailySummary { store.dailySummary(for: today) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Date header
                    Text(DateFormatter.display.string(from: Date()))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal)

                    // Energy ring card
                    EnergyRingCard(summary: summary)
                        .padding(.horizontal)

                    // Stats grid
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        StatCard(
                            title: "Resting",
                            value: "\(Int(summary.energy?.restingKcal ?? 0))",
                            unit: "kcal",
                            icon: "zzz",
                            color: .blue
                        )
                        StatCard(
                            title: "Active",
                            value: "\(Int(summary.energy?.activeKcal ?? 0))",
                            unit: "kcal",
                            icon: "figure.run",
                            color: .orange
                        )
                        StatCard(
                            title: "Sleep",
                            value: String(format: "%.1f", summary.energy?.sleepHours ?? 0),
                            unit: "hrs",
                            icon: "moon.stars.fill",
                            color: .indigo
                        )
                        StatCard(
                            title: "Weight",
                            value: summary.weight.map { String(format: "%.1f", $0.kg) } ?? "--",
                            unit: "kg",
                            icon: "scalemass.fill",
                            color: .green
                        )
                    }
                    .padding(.horizontal)

                    // Meals intake row
                    MealSummaryRow(meals: summary.meals)
                        .padding(.horizontal)

                    // Net energy
                    NetEnergyCard(net: summary.netEnergy, intake: summary.totalIntake, burned: summary.totalBurned)
                        .padding(.horizontal)

                    // Weight input
                    WeightInputCard(today: today)
                        .padding(.horizontal)

                    Spacer(minLength: 20)
                }
                .padding(.top, 8)
            }
            .navigationTitle("Myhealth")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task { await refresh() }
                    } label: {
                        if isRefreshing {
                            ProgressView().scaleEffect(0.8)
                        } else {
                            Image(systemName: "arrow.clockwise")
                        }
                    }
                }
            }
            .task { await refresh() }
        }
    }

    private func refresh() async {
        isRefreshing = true
        let energy = await healthKit.fetchDailyEnergy(for: today)
        store.upsertEnergy(energy)
        isRefreshing = false
    }
}

// MARK: - Energy Ring Card

struct EnergyRingCard: View {
    let summary: DailySummary

    private var progress: Double {
        guard summary.totalBurned > 0 else { return 0 }
        return min(summary.totalIntake / summary.totalBurned, 1.5)
    }

    var body: some View {
        HStack(spacing: 24) {
            ZStack {
                Circle()
                    .stroke(Color(.systemFill), lineWidth: 16)
                    .frame(width: 120, height: 120)

                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(
                        LinearGradient(colors: [.orange, .pink], startPoint: .topLeading, endPoint: .bottomTrailing),
                        style: StrokeStyle(lineWidth: 16, lineCap: .round)
                    )
                    .frame(width: 120, height: 120)
                    .rotationEffect(.degrees(-90))
                    .animation(.easeOut(duration: 0.8), value: progress)

                VStack(spacing: 2) {
                    Text("\(Int(summary.totalIntake))")
                        .font(.title2.bold())
                    Text("kcal in")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            VStack(alignment: .leading, spacing: 10) {
                LabeledValue(label: "Intake", value: "\(Int(summary.totalIntake)) kcal", color: .orange)
                LabeledValue(label: "Burned", value: "\(Int(summary.totalBurned)) kcal", color: .red)
                Divider()
                LabeledValue(
                    label: "Balance",
                    value: "\(summary.netEnergy >= 0 ? "+" : "")\(Int(summary.netEnergy)) kcal",
                    color: summary.netEnergy > 200 ? .red : summary.netEnergy < -200 ? .blue : .green
                )
            }
            Spacer()
        }
        .padding(20)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
    }
}

struct LabeledValue: View {
    let label: String
    let value: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(label).font(.caption).foregroundStyle(.secondary)
            Text(value).font(.subheadline.bold()).foregroundColor(color)
        }
    }
}

// MARK: - Stat Card

struct StatCard: View {
    let title: String
    let value: String
    let unit: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundStyle(color)
                Spacer()
            }
            Text("\(value) \(unit)")
                .font(.title2.bold())
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }
}

// MARK: - Meal Summary Row

struct MealSummaryRow: View {
    let meals: [MealRecord]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Meals Today")
                .font(.headline)

            HStack(spacing: 12) {
                ForEach(MealType.allCases, id: \.self) { type in
                    let meal = meals.first { $0.type == type }
                    MealChip(type: type, meal: meal)
                }
            }
        }
        .padding(16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }
}

struct MealChip: View {
    let type: MealType
    let meal: MealRecord?

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: type.icon)
                .font(.title3)
                .foregroundStyle(meal != nil ? .primary : .tertiary)
            Text(type.rawValue)
                .font(.caption2)
                .foregroundStyle(.secondary)
            if let cal = meal?.calories {
                Text("\(Int(cal)) kcal")
                    .font(.caption.bold())
            } else {
                Text("--")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(meal != nil ? Color.accentColor.opacity(0.1) : Color(.systemFill), in: RoundedRectangle(cornerRadius: 10))
    }
}

// MARK: - Net Energy Card

struct NetEnergyCard: View {
    let net: Double
    let intake: Double
    let burned: Double

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Energy Balance")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("\(net >= 0 ? "+" : "")\(Int(net)) kcal")
                    .font(.title3.bold())
                    .foregroundColor(net > 300 ? .red : net < -300 ? .blue : .green)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                Text("Intake \(Int(intake)) / Burned \(Int(burned))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(net > 0 ? "Surplus" : net < 0 ? "Deficit" : "Balanced")
                    .font(.caption.bold())
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(net > 300 ? Color.red.opacity(0.15) : net < -300 ? Color.blue.opacity(0.15) : Color.green.opacity(0.15), in: Capsule())
            }
        }
        .padding(16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }
}

// MARK: - Weight Input Card

struct WeightInputCard: View {
    let today: Date
    @StateObject private var store = DataStore.shared
    @State private var weightText = ""
    @State private var showInput = false

    var currentWeight: WeightRecord? { store.weight(for: today) }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "scalemass.fill").foregroundStyle(.green)
                Text("Weight").font(.headline)
                Spacer()
                Button(showInput ? "Cancel" : "Edit") {
                    showInput.toggle()
                    if showInput {
                        weightText = currentWeight.map { String(format: "%.1f", $0.kg) } ?? ""
                    }
                }
                .font(.subheadline)
            }

            if showInput {
                HStack {
                    TextField("kg", text: $weightText)
                        .keyboardType(.decimalPad)
                        .textFieldStyle(.roundedBorder)
                    Button("Save") {
                        if let kg = Double(weightText), kg > 0 {
                            store.upsertWeight(WeightRecord(date: today, kg: kg))
                            showInput = false
                        }
                    }
                    .buttonStyle(.borderedProminent)
                }
            } else {
                Text(currentWeight.map { String(format: "%.1f kg", $0.kg) } ?? "Tap Edit to log weight")
                    .foregroundStyle(currentWeight != nil ? .primary : .tertiary)
                    .font(.subheadline)
            }
        }
        .padding(16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }
}

#Preview {
    DashboardView()
}
