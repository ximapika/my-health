import SwiftUI
import PhotosUI

struct MealView: View {
    @StateObject private var store = DataStore.shared
    @State private var selectedDate = Calendar.current.startOfDay(for: Date())

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    // Date picker
                    DatePicker("Date", selection: $selectedDate, displayedComponents: .date)
                        .datePickerStyle(.compact)
                        .padding(.horizontal)

                    ForEach(MealType.allCases, id: \.self) { type in
                        MealCard(date: selectedDate, mealType: type)
                            .padding(.horizontal)
                    }

                    Spacer(minLength: 20)
                }
                .padding(.top, 12)
            }
            .navigationTitle("Meals")
            .navigationBarTitleDisplayMode(.large)
        }
    }
}

// MARK: - Meal Card

struct MealCard: View {
    let date: Date
    let mealType: MealType

    @StateObject private var store = DataStore.shared
    @State private var showPhotoPicker = false
    @State private var pickerItem: PhotosPickerItem?
    @State private var errorMessage: String?

    private var meal: MealRecord? {
        store.meals(for: date).first { $0.type == mealType }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Image(systemName: mealType.icon)
                    .font(.title3)
                    .foregroundStyle(.orange)
                Text(mealType.rawValue)
                    .font(.headline)
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

            // Image / Add button
            if let imageData = meal?.imageData, let uiImage = UIImage(data: imageData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity)
                    .frame(height: 180)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .onTapGesture { showPhotoPicker = true }
            } else {
                PhotosPickerButton(showPicker: $showPhotoPicker)
            }

            // Calories & description
            if let meal = meal {
                if meal.isAnalyzing {
                    HStack {
                        ProgressView()
                        Text("Analyzing with AI…")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                } else if let cal = meal.calories {
                    HStack {
                        Image(systemName: "flame.fill").foregroundStyle(.orange)
                        Text("\(Int(cal)) kcal")
                            .font(.subheadline.bold())
                        Spacer()
                        Button("Re-analyze") {
                            Task { await analyze(meal: meal) }
                        }
                        .font(.caption)
                    }
                    if let desc = meal.aiDescription {
                        Text(desc)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(3)
                    }
                }
            }

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
    }

    // MARK: - Photo handling

    private func handlePickedItem(_ item: PhotosPickerItem?) async {
        guard let item else { return }
        errorMessage = nil

        guard let data = try? await item.loadTransferable(type: Data.self),
              let image = UIImage(data: data) else {
            errorMessage = "Failed to load image."
            return
        }

        var record = MealRecord(date: date, type: mealType, imageData: image.jpegData(compressionQuality: 0.85))
        record.isAnalyzing = true
        store.upsertMeal(record)

        await analyze(meal: record)
    }

    private func analyze(meal: MealRecord) async {
        guard let imageData = meal.imageData, let image = UIImage(data: imageData) else { return }

        var updated = meal
        updated.isAnalyzing = true
        store.upsertMeal(updated)

        do {
            let result = try await AIService.shared.analyzeMeal(image: image, mealType: mealType)
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
    MealView()
}
