import SwiftUI

struct PlannerView: View {
    @StateObject private var store = DataStore.shared
    @State private var showAddItem = false

    private let calendar = Calendar.current

    private var pendingItems: [PlannerItem] {
        store.plannerItems.filter { !$0.isCompleted }
    }

    private var completedItems: [PlannerItem] {
        store.plannerItems.filter(\.isCompleted)
    }

    private var dueTodayCount: Int {
        pendingItems.filter { calendar.isDateInToday($0.deadline) }.count
    }

    private var overdueCount: Int {
        pendingItems.filter { $0.deadline < Date() }.count
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    PlannerOverviewCard(
                        pendingCount: pendingItems.count,
                        dueTodayCount: dueTodayCount,
                        overdueCount: overdueCount,
                        onAdd: { showAddItem = true }
                    )
                    .padding(.horizontal)

                    if store.plannerItems.isEmpty {
                        PlannerEmptyState(onAdd: { showAddItem = true })
                            .padding(.horizontal)
                    } else {
                        if !pendingItems.isEmpty {
                            PlannerContentSection(title: "Up Next", subtitle: "Sorted by nearest deadline") {
                                ForEach(pendingItems) { item in
                                    PlannerItemCard(
                                        item: item,
                                        onToggleCompleted: {
                                            store.togglePlannerItemCompletion(id: item.id)
                                        },
                                        onDelete: {
                                            store.deletePlannerItem(id: item.id)
                                        }
                                    )
                                }
                            }
                            .padding(.horizontal)
                        }

                        if !completedItems.isEmpty {
                            PlannerContentSection(title: "Completed", subtitle: "\(completedItems.count) item\(completedItems.count == 1 ? "" : "s")") {
                                ForEach(completedItems) { item in
                                    PlannerItemCard(
                                        item: item,
                                        onToggleCompleted: {
                                            store.togglePlannerItemCompletion(id: item.id)
                                        },
                                        onDelete: {
                                            store.deletePlannerItem(id: item.id)
                                        }
                                    )
                                }
                            }
                            .padding(.horizontal)
                        }
                    }

                    Spacer(minLength: 20)
                }
                .padding(.top, 12)
            }
            .navigationTitle("Planner")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showAddItem = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showAddItem) {
                AddPlannerItemSheet()
            }
        }
    }
}

struct PlannerOverviewCard: View {
    let pendingCount: Int
    let dueTodayCount: Int
    let overdueCount: Int
    let onAdd: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Planning")
                        .font(.headline)
                    Text("Keep your next actions visible and in deadline order.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button(action: onAdd) {
                    Label("Add", systemImage: "plus.circle.fill")
                        .font(.subheadline.weight(.semibold))
                }
                .buttonStyle(.borderedProminent)
            }

            HStack(spacing: 12) {
                PlannerMetricCard(title: "Pending", value: "\(pendingCount)", tint: .blue)
                PlannerMetricCard(title: "Due Today", value: "\(dueTodayCount)", tint: .orange)
                PlannerMetricCard(title: "Overdue", value: "\(overdueCount)", tint: .red)
            }
        }
        .padding(16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
    }
}

struct PlannerMetricCard: View {
    let title: String
    let value: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.title3.bold())
                .foregroundStyle(tint)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 16))
    }
}

struct PlannerContentSection<Content: View>: View {
    let title: String
    let subtitle: String
    let content: Content

    init(title: String, subtitle: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.subtitle = subtitle
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            content
        }
    }
}

struct PlannerItemCard: View {
    let item: PlannerItem
    let onToggleCompleted: () -> Void
    let onDelete: () -> Void

    private let calendar = Calendar.current

    private var deadlineLabel: String {
        item.deadline.formatted(date: .abbreviated, time: .shortened)
    }

    private var statusTitle: String {
        if item.isCompleted {
            return "Done"
        }
        if item.deadline < Date() {
            return "Overdue"
        }
        if calendar.isDateInToday(item.deadline) {
            return "Today"
        }
        return "Upcoming"
    }

    private var statusColor: Color {
        if item.isCompleted {
            return .green
        }
        if item.deadline < Date() {
            return .red
        }
        if calendar.isDateInToday(item.deadline) {
            return .orange
        }
        return .blue
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Button(action: onToggleCompleted) {
                Image(systemName: item.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(item.isCompleted ? .green : .secondary)
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top, spacing: 8) {
                    Text(item.title)
                        .font(.headline)
                        .foregroundStyle(item.isCompleted ? .secondary : .primary)
                        .strikethrough(item.isCompleted, color: .secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Text(statusTitle)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(statusColor)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(statusColor.opacity(0.12), in: Capsule())
                }

                VStack(alignment: .leading, spacing: 4) {
                    Label(deadlineLabel, systemImage: "calendar")
                        .font(.subheadline)
                        .foregroundStyle(.primary)

                    if !item.isCompleted {
                        Text(item.deadline, style: .relative)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else if let completedAt = item.completedAt {
                        Text("Completed \(completedAt.formatted(date: .abbreviated, time: .shortened))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Button(role: .destructive, action: onDelete) {
                Image(systemName: "trash")
                    .font(.subheadline)
                    .foregroundStyle(.red)
            }
            .buttonStyle(.plain)
        }
        .padding(16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18))
    }
}

struct PlannerEmptyState: View {
    let onAdd: () -> Void

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "checklist")
                .font(.largeTitle)
                .foregroundStyle(.tertiary)

            Text("No planner items yet")
                .font(.headline)

            Text("Add a title and deadline. The closest deadline will always stay at the top.")
                .multilineTextAlignment(.center)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Button(action: onAdd) {
                Label("Create First Item", systemImage: "plus.circle.fill")
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
        .padding(.horizontal, 24)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
    }
}

struct AddPlannerItemSheet: View {
    @StateObject private var store = DataStore.shared
    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var deadline = PlannerDeadlineDefaults.defaultDeadline

    private var trimmedTitle: String {
        title.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("e.g. Annual health check booking", text: $title)
                } header: {
                    Text("Title")
                }

                Section {
                    DatePicker(
                        "Date & Time",
                        selection: $deadline,
                        displayedComponents: [.date, .hourAndMinute]
                    )
                } header: {
                    Text("Deadline")
                } footer: {
                    Text("Items are sorted automatically so the nearest deadline appears first.")
                }
            }
            .navigationTitle("New Planner Item")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        let item = PlannerItem(title: trimmedTitle, deadline: deadline)
                        store.upsertPlannerItem(item)
                        dismiss()
                    }
                    .disabled(trimmedTitle.isEmpty)
                }
            }
        }
        .presentationDetents([.medium])
    }
}

enum PlannerDeadlineDefaults {
    static var defaultDeadline: Date {
        let calendar = Calendar.current
        let now = Date()
        if let date = calendar.date(bySettingHour: 18, minute: 0, second: 0, of: now),
           date > now {
            return date
        }
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: now) ?? now
        return calendar.date(bySettingHour: 18, minute: 0, second: 0, of: tomorrow) ?? tomorrow
    }
}

#Preview {
    PlannerView()
}
