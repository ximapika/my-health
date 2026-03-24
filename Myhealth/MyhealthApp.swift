import SwiftUI

@main
struct MyhealthApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(DataStore.shared)
                .environmentObject(HealthKitManager.shared)
        }
    }
}
