import SwiftUI
import PhotosUI

// MARK: - Meal View

struct MealView: View {
    @StateObject private var store = DataStore.shared
    @Binding var selectedDate: Date
    @State private var showAddCustomMeal = false

    private let calendar = Calendar.current

    private var today: Date { calendar.startOfDay(for: Date()) }
    private var selectedDateBinding: Binding<Date> {
        Binding(
            get: { selectedDate },
            set: { newValue in
                selectedDate = min(calendar.startOfDay(for: newValue), today)
            }
        )
    }

    private var customMeals: [MealRecord] {
        store.meals(for: selectedDate).filter { $0.type == .custom }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                DatePicker("Date", selection: selectedDateBinding, in: ...today, displayedComponents: .date)
                    .datePickerStyle(.compact)
                    .padding(.horizontal)

                // Standard meals
                ForEach(MealType.standardCases, id: \.self) { type in
                    MealCard(date: selectedDate, mealType: type)
                        .padding(.horizontal)
                }

                // Custom meals
                ForEach(customMeals) { meal in
                    MealCard(date: selectedDate, mealType: .custom, mealID: meal.id)
                        .padding(.horizontal)
                }

                Button {
                    showAddCustomMeal = true
                } label: {
                    Label("Add Custom Meal", systemImage: "plus.circle.fill")
                        .font(.subheadline)
                }
                .buttonStyle(.bordered)
                .padding(.horizontal)

                Spacer(minLength: 20)
            }
            .padding(.top, 12)
        }
        .navigationTitle("Meals")
        .navigationBarTitleDisplayMode(.large)
        .sheet(isPresented: $showAddCustomMeal) {
            AddCustomMealSheet(date: selectedDate)
        }
    }
}

// MARK: - Meal Card

struct MealCard: View {
    let date: Date
    let mealType: MealType
    var mealID: UUID? = nil  // set for custom meals to identify the specific record

    @StateObject private var store = DataStore.shared
    @State private var showPhotoPicker = false
    @State private var pickerItem: PhotosPickerItem?
    @State private var errorMessage: String?
    @State private var showImageViewer = false
    @State private var showCalorieEditor = false
    @State private var editingName = false
    @State private var nameInput = ""

    private var meal: MealRecord? {
        if let id = mealID {
            return store.meals.first { $0.id == id }
        }
        return store.meals(for: date).first { $0.type == mealType }
    }

    private var isCustom: Bool { mealType == .custom }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            headerView
            photoArea
            calorieArea

            if let err = errorMessage {
                Text(err)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
        .padding(16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
        .photosPicker(isPresented: $showPhotoPicker, selection: $pickerItem, matching: .images)
        .onChange(of: pickerItem) { _, item in
            Task { await handlePickedItem(item) }
        }
        .sheet(isPresented: $showImageViewer) {
            ImageViewerSheet(imageData: meal?.imageData)
        }
        .sheet(isPresented: $showCalorieEditor) {
            CalorieEditorSheet(current: meal?.calories) { newValue in
                if var updated = meal {
                    updated.calories = newValue
                    store.upsertMeal(updated)
                }
            }
        }
    }

    // MARK: - Header

    @ViewBuilder
    private var headerView: some View {
        HStack {
            Image(systemName: mealType.icon)
                .font(.title3)
                .foregroundStyle(.orange)

            if isCustom && editingName {
                TextField("Meal name", text: $nameInput)
                    .font(.headline)
                    .onSubmit { saveCustomName() }
                Button(action: saveCustomName) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                }
            } else {
                Text(meal?.displayName ?? mealType.rawValue)
                    .font(.headline)
                if isCustom {
                    Button {
                        nameInput = meal?.customName ?? ""
                        editingName = true
                    } label: {
                        Image(systemName: "pencil")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Spacer()

            if meal != nil {
                Button(role: .destructive) {
                    if let m = meal { store.deleteMeal(id: m.id) }
                } label: {
                    Image(systemName: "trash")
                        .foregroundStyle(.red)
                }
            }
        }
    }

    // MARK: - Photo Area

    @ViewBuilder
    private var photoArea: some View {
        if let imageData = meal?.imageData, let uiImage = UIImage(data: imageData) {
            ZStack(alignment: .topTrailing) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity)
                    .frame(height: 180)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .contentShape(RoundedRectangle(cornerRadius: 12))
                    .onTapGesture { showImageViewer = true }

                HStack(spacing: 6) {
                    // Delete photo
                    Button(action: deletePhoto) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundStyle(.white)
                            .shadow(color: .black.opacity(0.5), radius: 2)
                    }
                    // Replace photo
                    Button { showPhotoPicker = true } label: {
                        Image(systemName: "arrow.triangle.2.circlepath.circle.fill")
                            .font(.title2)
                            .foregroundStyle(.white)
                            .shadow(color: .black.opacity(0.5), radius: 2)
                    }
                }
                .padding(8)
            }
        } else {
            PhotosPickerButton(showPicker: $showPhotoPicker)
        }
    }

    // MARK: - Calorie Area

    @ViewBuilder
    private var calorieArea: some View {
        if let meal = meal {
            if meal.isAnalyzing {
                HStack {
                    ProgressView()
                    Text("Analyzing with AI…")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            } else {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Image(systemName: "flame.fill").foregroundStyle(.orange)
                        if let cal = meal.calories {
                            Text("\(Int(cal)) kcal")
                                .font(.subheadline.bold())
                        } else {
                            Text("— kcal")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        Button {
                            showCalorieEditor = true
                        } label: {
                            Image(systemName: "pencil")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)

                        Spacer()

                        if meal.imageData != nil {
                            Button("Re-analyze") {
                                Task { await analyze(meal: meal) }
                            }
                            .font(.caption)
                        }
                    }

                    if let desc = meal.aiDescription {
                        Text(desc)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(3)
                    }
                }
            }
        }
    }

    // MARK: - Actions

    private func saveCustomName() {
        if var updated = meal {
            updated.customName = nameInput.trimmingCharacters(in: .whitespaces).isEmpty ? nil : nameInput
            store.upsertMeal(updated)
        }
        editingName = false
    }

    private func deletePhoto() {
        guard var updated = meal else { return }
        updated.imageData = nil
        updated.calories = nil
        updated.aiDescription = nil
        store.upsertMeal(updated)
    }

    private func handlePickedItem(_ item: PhotosPickerItem?) async {
        guard let item else { return }
        errorMessage = nil

        guard let data = try? await item.loadTransferable(type: Data.self),
              let image = UIImage(data: data) else {
            errorMessage = "Failed to load image."
            return
        }

        let imageData = image.jpegData(compressionQuality: 0.85)

        if var existing = meal {
            // Replace photo in existing record
            existing.imageData = imageData
            existing.calories = nil
            existing.aiDescription = nil
            existing.isAnalyzing = true
            store.upsertMeal(existing)
            await analyze(meal: existing)
        } else {
            // Create new record for standard meal
            var record = MealRecord(date: date, type: mealType, imageData: imageData)
            record.isAnalyzing = true
            store.upsertMeal(record)
            await analyze(meal: record)
        }
    }

    private func analyze(meal: MealRecord) async {
        guard let imageData = meal.imageData, let image = UIImage(data: imageData) else { return }

        var updated = meal
        updated.isAnalyzing = true
        store.upsertMeal(updated)

        do {
            let result = try await AIService.shared.analyzeMeal(image: image, mealLabel: meal.displayName)
            updated.calories = result.calories
            updated.aiDescription = result.description
            updated.isAnalyzing = false
            store.upsertMeal(updated)
        } catch {
            updated.isAnalyzing = false
            store.upsertMeal(updated)
            errorMessage = error.localizedDescription
        }
    }
}

// MARK: - Image Viewer Sheet

struct ImageViewerSheet: View {
    let imageData: Data?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Group {
                if let data = imageData, let uiImage = UIImage(data: data) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFit()
                        .ignoresSafeArea(edges: .bottom)
                } else {
                    ContentUnavailableView("No Image", systemImage: "photo")
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Calorie Editor Sheet

struct CalorieEditorSheet: View {
    let current: Double?
    let onSave: (Double) -> Void

    @State private var input: String
    @Environment(\.dismiss) private var dismiss

    init(current: Double?, onSave: @escaping (Double) -> Void) {
        self.current = current
        self.onSave = onSave
        _input = State(initialValue: current.map { "\(Int($0))" } ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("e.g. 500", text: $input)
                        .keyboardType(.decimalPad)
                } header: {
                    Text("Calories (kcal)")
                }
            }
            .navigationTitle("Edit Calories")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        if let val = Double(input) { onSave(val) }
                        dismiss()
                    }
                    .disabled(Double(input) == nil)
                }
            }
        }
        .presentationDetents([.height(220)])
    }
}

// MARK: - Add Custom Meal Sheet

struct AddCustomMealSheet: View {
    let date: Date

    @StateObject private var store = DataStore.shared
    @State private var mealName = ""
    @Environment(\.dismiss) private var dismiss

    var trimmedName: String { mealName.trimmingCharacters(in: .whitespaces) }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("e.g. Afternoon Snack", text: $mealName)
                } header: {
                    Text("Meal Name")
                }
            }
            .navigationTitle("New Custom Meal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        let record = MealRecord(date: date, type: .custom, customName: trimmedName)
                        store.upsertMeal(record)
                        dismiss()
                    }
                    .disabled(trimmedName.isEmpty)
                }
            }
        }
        .presentationDetents([.height(200)])
    }
}

// MARK: - Photos Picker Button

struct PhotosPickerButton: View {
    @Binding var showPicker: Bool

    var body: some View {
        Button {
            showPicker = true
        } label: {
            VStack(spacing: 8) {
                Image(systemName: "camera.fill")
                    .font(.title2)
                    .foregroundStyle(.secondary)
                Text("Add Photo")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 100)
            .background(Color(.systemFill), in: RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    NavigationStack {
        MealView(selectedDate: .constant(Calendar.current.startOfDay(for: Date())))
    }
}
