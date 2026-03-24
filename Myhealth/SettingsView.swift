import SwiftUI

struct SettingsView: View {
    @StateObject private var store = DataStore.shared
    @StateObject private var healthKit = HealthKitManager.shared
    @State private var apiKeyInput = ""
    @State private var showKey = false
    @State private var saved = false

    var body: some View {
        NavigationStack {
            Form {
                // API Key
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Anthropic API Key")
                            .font(.subheadline.bold())
                        HStack {
                            Group {
                                if showKey {
                                    TextField("sk-ant-...", text: $apiKeyInput)
                                } else {
                                    SecureField("sk-ant-...", text: $apiKeyInput)
                                }
                            }
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .font(.caption.monospaced())

                            Button {
                                showKey.toggle()
                            } label: {
                                Image(systemName: showKey ? "eye.slash" : "eye")
                                    .foregroundStyle(.secondary)
                            }
                        }

                        Button {
                            store.apiKey = apiKeyInput
                            saved = true
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { saved = false }
                        } label: {
                            HStack {
                                Image(systemName: saved ? "checkmark.circle.fill" : "square.and.arrow.down")
                                Text(saved ? "Saved!" : "Save Key")
                            }
                            .font(.subheadline)
                        }
                        .buttonStyle(.bordered)
                        .tint(saved ? .green : .accentColor)

                        Text("Used for meal calorie analysis and report generation. Your key is stored locally on your device.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                } header: {
                    Text("AI Configuration")
                }

                // HealthKit
                Section {
                    HStack {
                        Image(systemName: healthKit.isAuthorized ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .foregroundStyle(healthKit.isAuthorized ? .green : .red)
                        Text(healthKit.isAuthorized ? "Access granted" : "Access not granted")
                            .font(.subheadline)
                        Spacer()
                        if !healthKit.isAuthorized {
                            Button("Request") {
                                Task { await healthKit.requestAuthorization() }
                            }
                            .buttonStyle(.bordered)
                            .font(.caption)
                        }
                    }
                    if let err = healthKit.authError {
                        Text(err)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                } header: {
                    Text("HealthKit")
                } footer: {
                    Text("Reads resting energy, active energy, and sleep data from the Health app.")
                }

                // Data
                Section {
                    HStack {
                        Image(systemName: "fork.knife")
                        Text("Meal records")
                        Spacer()
                        Text("\(store.meals.count)")
                            .foregroundStyle(.secondary)
                    }
                    HStack {
                        Image(systemName: "scalemass.fill")
                        Text("Weight records")
                        Spacer()
                        Text("\(store.weights.count)")
                            .foregroundStyle(.secondary)
                    }
                    HStack {
                        Image(systemName: "doc.text")
                        Text("Reports saved")
                        Spacer()
                        Text("\(store.reports.count)")
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    Text("Data")
                }

                // About
                Section {
                    LabeledContent("Version", value: "1.0.0")
                    LabeledContent("AI Model", value: "claude-opus-4-6")
                } header: {
                    Text("About")
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
            .onAppear {
                apiKeyInput = store.apiKey
            }
        }
    }
}

#Preview {
    SettingsView()
}
