import SwiftUI

struct SettingsView: View {
    @StateObject private var store = DataStore.shared
    @StateObject private var healthKit = HealthKitManager.shared
    @State private var showAddModel = false
    @State private var editingConfig: AIModelConfig?

    var body: some View {
        NavigationStack {
            Form {
                // AI Models
                Section {
                    ForEach(store.modelConfigs) { config in
                        ModelConfigRow(
                            config: config,
                            isSelected: store.selectedModel?.id == config.id,
                            onSelect: { store.selectedModelID = config.id.uuidString },
                            onEdit: { editingConfig = config }
                        )
                    }
                    .onDelete { indexSet in
                        indexSet.forEach { store.deleteModelConfig(id: store.modelConfigs[$0].id) }
                    }

                    Button {
                        showAddModel = true
                    } label: {
                        Label("Add Model", systemImage: "plus.circle")
                    }
                } header: {
                    Text("AI Models")
                } footer: {
                    Text("Tap a model to select it. Supports Anthropic and OpenAI-compatible APIs (e.g. Qwen, DeepSeek).")
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
                        Image(systemName: "checklist")
                        Text("Planner items")
                        Spacer()
                        Text("\(store.plannerItems.count)")
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
                    if let model = store.selectedModel {
                        LabeledContent("Active Model", value: model.name)
                        LabeledContent("Provider", value: model.provider.rawValue)
                    }
                } header: {
                    Text("About")
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
            .sheet(isPresented: $showAddModel) {
                ModelConfigEditorView(
                    config: AIModelConfig(name: "", provider: .anthropic,
                                         apiURL: AIProvider.anthropic.defaultURL,
                                         apiKey: "", modelID: "", supportsVision: true),
                    isNew: true
                ) { saved in
                    store.upsertModelConfig(saved)
                    if store.selectedModelID == nil {
                        store.selectedModelID = saved.id.uuidString
                    }
                    showAddModel = false
                } onCancel: {
                    showAddModel = false
                }
            }
            .sheet(item: $editingConfig) { config in
                ModelConfigEditorView(config: config, isNew: false) { saved in
                    store.upsertModelConfig(saved)
                    editingConfig = nil
                } onCancel: {
                    editingConfig = nil
                }
            }
        }
    }
}

// MARK: - Model Config Row

struct ModelConfigRow: View {
    let config: AIModelConfig
    let isSelected: Bool
    let onSelect: () -> Void
    let onEdit: () -> Void

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(config.name)
                        .font(.subheadline.bold())
                    if config.supportsVision {
                        Image(systemName: "camera.fill")
                            .font(.caption2)
                            .foregroundStyle(.blue)
                    }
                }
                Text("\(config.provider.rawValue) · \(config.modelID)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(Color.accentColor)
            }
            Button(action: onEdit) {
                Image(systemName: "pencil.circle")
                    .foregroundStyle(.secondary)
                    .font(.title3)
            }
            .buttonStyle(.plain)
        }
        .contentShape(Rectangle())
        .onTapGesture(perform: onSelect)
    }
}

// MARK: - Model Config Editor

struct ModelConfigEditorView: View {
    let isNew: Bool
    let onSave: (AIModelConfig) -> Void
    let onCancel: () -> Void

    @State private var id: UUID
    @State private var name: String
    @State private var provider: AIProvider
    @State private var apiURL: String
    @State private var apiKey: String
    @State private var modelID: String
    @State private var supportsVision: Bool
    @State private var showKey = false

    init(config: AIModelConfig, isNew: Bool, onSave: @escaping (AIModelConfig) -> Void, onCancel: @escaping () -> Void) {
        self.isNew = isNew
        self.onSave = onSave
        self.onCancel = onCancel
        _id = State(initialValue: config.id)
        _name = State(initialValue: config.name)
        _provider = State(initialValue: config.provider)
        _apiURL = State(initialValue: config.apiURL)
        _apiKey = State(initialValue: config.apiKey)
        _modelID = State(initialValue: config.modelID)
        _supportsVision = State(initialValue: config.supportsVision)
    }

    var canSave: Bool {
        !name.isEmpty && !apiURL.isEmpty && !modelID.isEmpty && !apiKey.isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Display Name") {
                    TextField("e.g. Qwen VL Max", text: $name)
                }

                Section("Provider") {
                    Picker("Provider", selection: $provider) {
                        ForEach(AIProvider.allCases, id: \.self) { p in
                            Text(p.rawValue).tag(p)
                        }
                    }
                    .onChange(of: provider) { old, new in
                        if apiURL == old.defaultURL {
                            apiURL = new.defaultURL
                        }
                    }
                }

                Section {
                    TextField("API URL", text: $apiURL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .font(.caption.monospaced())
                    TextField("Model ID  (e.g. qwen-vl-max)", text: $modelID)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    Toggle("Supports Image Analysis", isOn: $supportsVision)
                } header: {
                    Text("Model")
                } footer: {
                    Text("Qwen vision models: qwen-vl-max, qwen-vl-plus. For Alibaba Cloud use the DashScope compatible endpoint.")
                }

                Section("API Key") {
                    HStack {
                        Group {
                            if showKey {
                                TextField(provider.apiKeyPlaceholder, text: $apiKey)
                            } else {
                                SecureField(provider.apiKeyPlaceholder, text: $apiKey)
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
                }
            }
            .navigationTitle(isNew ? "Add Model" : "Edit Model")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onCancel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(AIModelConfig(id: id, name: name, provider: provider,
                                            apiURL: apiURL, apiKey: apiKey,
                                            modelID: modelID, supportsVision: supportsVision))
                    }
                    .disabled(!canSave)
                }
            }
        }
    }
}

#Preview {
    SettingsView()
}
