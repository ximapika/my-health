import SwiftUI

struct ReportView: View {
    @StateObject private var store = DataStore.shared
    @State private var isGeneratingDaily = false
    @State private var isGeneratingWeekly = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    // Generate buttons
                    HStack(spacing: 12) {
                        GenerateButton(
                            title: "Daily Report",
                            icon: "doc.text",
                            color: .blue,
                            isLoading: isGeneratingDaily
                        ) {
                            Task { await generateDaily() }
                        }

                        GenerateButton(
                            title: "Weekly Report",
                            icon: "calendar.badge.clock",
                            color: .purple,
                            isLoading: isGeneratingWeekly
                        ) {
                            Task { await generateWeekly() }
                        }
                    }
                    .padding(.horizontal)

                    if let err = errorMessage {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(.orange)
                            Text(err)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal)
                    }

                    if store.reports.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "doc.text.magnifyingglass")
                                .font(.largeTitle)
                                .foregroundStyle(.tertiary)
                            Text("No reports yet.\nTap a button above to generate your first report.")
                                .multilineTextAlignment(.center)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.top, 60)
                    } else {
                        ForEach(store.reports) { report in
                            ReportCard(report: report)
                                .padding(.horizontal)
                        }
                    }

                    Spacer(minLength: 20)
                }
                .padding(.top, 12)
            }
            .navigationTitle("Reports")
            .navigationBarTitleDisplayMode(.large)
        }
    }

    // MARK: - Generate

    private func generateDaily() async {
        errorMessage = nil
        isGeneratingDaily = true
        let today = Calendar.current.startOfDay(for: Date())
        let summary = store.dailySummary(for: today)

        do {
            let content = try await AIService.shared.generateDailyReport(summary: summary)
            let report = Report(createdAt: Date(), type: .daily, content: content)
            store.addReport(report)
        } catch {
            errorMessage = error.localizedDescription
        }
        isGeneratingDaily = false
    }

    private func generateWeekly() async {
        errorMessage = nil
        isGeneratingWeekly = true
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        var summaries: [DailySummary] = []
        for i in 0..<7 {
            if let day = calendar.date(byAdding: .day, value: -i, to: today) {
                summaries.append(store.dailySummary(for: day))
            }
        }

        do {
            let content = try await AIService.shared.generateWeeklyReport(summaries: summaries.reversed())
            let report = Report(createdAt: Date(), type: .weekly, content: content)
            store.addReport(report)
        } catch {
            errorMessage = error.localizedDescription
        }
        isGeneratingWeekly = false
    }
}

// MARK: - Report Card

struct ReportCard: View {
    let report: Report
    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: report.type == .daily ? "doc.text.fill" : "calendar")
                        .foregroundStyle(report.type == .daily ? .blue : .purple)
                    Text(report.type.rawValue)
                        .font(.subheadline.bold())
                }
                Spacer()
                Text(RelativeDateTimeFormatter().localizedString(for: report.createdAt, relativeTo: Date()))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if isExpanded {
                Divider()
                Text(report.content)
                    .font(.subheadline)
                    .foregroundStyle(.primary)
                    .lineSpacing(4)
            } else {
                Text(report.content)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
            }
        }
        .padding(16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
        .onTapGesture { withAnimation(.easeInOut(duration: 0.2)) { isExpanded.toggle() } }
    }
}

// MARK: - Generate Button

struct GenerateButton: View {
    let title: String
    let icon: String
    let color: Color
    let isLoading: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                if isLoading {
                    ProgressView()
                        .tint(color)
                } else {
                    Image(systemName: icon)
                        .font(.title2)
                        .foregroundStyle(color)
                }
                Text(title)
                    .font(.subheadline.bold())
                    .foregroundStyle(isLoading ? .secondary : .primary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 20)
            .background(color.opacity(0.1), in: RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
        .disabled(isLoading)
    }
}

#Preview {
    ReportView()
}
