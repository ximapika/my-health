import SwiftUI

struct ContentView: View {
    @StateObject private var healthKit = HealthKitManager.shared

    var body: some View {
        TabView {
            DashboardView()
                .tabItem {
                    Label("Today", systemImage: "flame.fill")
                }

            HistoryView()
                .tabItem {
                    Label("History", systemImage: "chart.bar.fill")
                }

            ReportView()
                .tabItem {
                    Label("Reports", systemImage: "doc.text.fill")
                }

            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape.fill")
                }
        }
        .task {
            await healthKit.requestAuthorization()
        }
    }
}

#Preview {
    ContentView()
}
