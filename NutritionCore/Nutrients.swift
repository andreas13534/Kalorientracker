import Foundation

enum Nutrient: String, CaseIterable, Identifiable, Codable, Sendable {
    case calories, protein, carbohydrates, fat, fiber
    var id: String { rawValue }
    var title: String {
        switch self {
        case .calories: return "Kalorien"
        case .protein: return "Protein"
        case .carbohydrates: return "Kohlenhydrate"
        case .fat: return "Fett"
        case .fiber: return "Ballaststoffe"
        }
    }
    var unit: String { self == .calories ? "kcal" : "g" }
}

struct Nutrients: Codable, Equatable, Sendable {
    var calories: Double = 0
    var protein: Double = 0
    var carbohydrates: Double = 0
    var fat: Double = 0
    var fiber: Double = 0
    static let zero = Nutrients()

    enum CodingKeys: String, CodingKey {
        case calories = "calories_kcal", protein = "protein_g"
        case carbohydrates = "carbohydrates_g", fat = "fat_g", fiber = "fiber_g"
    }

    subscript(_ nutrient: Nutrient) -> Double {
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

    var isValid: Bool { Nutrient.allCases.allSatisfy { self[$0].isFinite && self[$0] >= 0 && self[$0] <= 1_000_000 } }
    static func + (lhs: Self, rhs: Self) -> Self {
        var result = lhs
        for nutrient in Nutrient.allCases { result[nutrient] += rhs[nutrient] }
        return result
    }

    static func sum<S: Sequence>(_ values: S) -> Self where S.Element == Self {
        values.reduce(.zero, +)
    }

    func progress(for nutrient: Nutrient, reference: Double?) -> Double? {
        guard let reference, reference.isFinite, reference > 0 else { return nil }
        return min(max(self[nutrient] / reference, 0), 1)
    }
}

enum NutritionNumber {
    static func parse(_ text: String) -> Double? {
        let cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: ",", with: ".")
        guard !cleaned.isEmpty, let value = Double(cleaned), value.isFinite, value >= 0, value <= 1_000_000 else { return nil }
        return value
    }
    static func display(_ value: Double) -> String {
        value.formatted(.number.locale(Locale(identifier: "de_AT")).precision(.fractionLength(0...1)))
    }
    static func edit(_ value: Double) -> String {
        String(value).replacingOccurrences(of: ".", with: ",")
    }
}

enum DayRange {
    static func interval(for date: Date, calendar: Calendar = .current) -> DateInterval {
        let start = calendar.startOfDay(for: date)
        let end = calendar.date(byAdding: .day, value: 1, to: start)!
        return DateInterval(start: start, end: end)
    }
    static func contains(_ date: Date, in day: Date, calendar: Calendar = .current) -> Bool {
        let range = interval(for: day, calendar: calendar)
        return date >= range.start && date < range.end
    }
}
