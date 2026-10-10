import Foundation
import SwiftData

@Model
final class Meal {
    @Attribute(.unique) var id: UUID
    var name: String
    var date: Date
    var notes: String
    var calories: Double
    var protein: Double
    var carbohydrates: Double
    var fat: Double
    var fiber: Double
    var photoFilename: String?
    var foodsData: Data
    var uncertaintyNotes: String
    var source: String

    init(name: String, date: Date = .now, nutrients: Nutrients = .zero, notes: String = "") {
        id = UUID(); self.name = name; self.date = date; self.notes = notes
        calories = nutrients.calories; protein = nutrients.protein
        carbohydrates = nutrients.carbohydrates; fat = nutrients.fat; fiber = nutrients.fiber
        foodsData = Data(); uncertaintyNotes = ""; source = "manual"
    }
    var nutrients: Nutrients {
        get { Nutrients(calories: calories, protein: protein, carbohydrates: carbohydrates, fat: fat, fiber: fiber) }
        set { calories = newValue.calories; protein = newValue.protein; carbohydrates = newValue.carbohydrates; fat = newValue.fat; fiber = newValue.fiber }
    }
    var foods: [FoodEstimate] { (try? JSONDecoder().decode([FoodEstimate].self, from: foodsData)) ?? [] }
}

@Model
final class UserSettings {
    @Attribute(.unique) var id: String
    var calories: Double?
    var protein: Double?
    var carbohydrates: Double?
    var fat: Double?
    var fiber: Double?
    var haptics: Bool
    var speechLocale: String
    init() { id = "settings"; haptics = true; speechLocale = "de-AT" }
    subscript(_ nutrient: Nutrient) -> Double? {
        get {
            switch nutrient {
            case .calories: return calories
            case .protein: return protein
            case .carbohydrates: return carbohydrates
            case .fat: return fat
            case .fiber: return fiber
            }
        }
        set {
            switch nutrient {
            case .calories: calories = newValue
            case .protein: protein = newValue
            case .carbohydrates: carbohydrates = newValue
            case .fat: fat = newValue
            case .fiber: fiber = newValue
            }
        }
    }
}

struct MealDraft: Identifiable {
    let id = UUID()
    var name = ""
    var date = Date.now
    var notes = ""
    var nutrients = Nutrients.zero
    var foods: [FoodEstimate] = []
    var uncertaintyNotes = ""
    var photoJPEG: Data?
    var photoFilename: String?
    var photoChanged = false
    var source = "manual"
    var editingMeal: Meal?
    var isValid: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && nutrients.isValid && foods.allSatisfy(\.isValid)
    }
    init(date: Date = .now) { self.date = date }
    init(meal: Meal) {
        name = meal.name; date = meal.date; notes = meal.notes; nutrients = meal.nutrients
        foods = meal.foods; uncertaintyNotes = meal.uncertaintyNotes; source = meal.source
        photoFilename = meal.photoFilename; editingMeal = meal
    }
    init(result: AnalysisResult, date: Date, notes: String, photo: Data?) {
        name = result.name; self.date = date; self.notes = notes; nutrients = result.totals
        foods = result.foods
        let confidence = ["low": "gering", "medium": "mittel", "high": "hoch"][result.confidence] ?? result.confidence
        uncertaintyNotes = (["Sicherheit der Schätzung: \(confidence)"] + result.uncertainties).joined(separator: "\n")
        photoJPEG = photo; photoChanged = photo != nil; source = photo == nil ? "ai_text" : "ai_photo"
    }
}
