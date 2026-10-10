import Foundation
import CoreFoundation

struct FoodEstimate: Codable, Identifiable, Equatable, Sendable {
    var id = UUID()
    var name: String
    var portion: String
    var nutrients: Nutrients
    var uncertainty: String
    enum CodingKeys: String, CodingKey { case id, name, portion, nutrients, uncertainty }
    init(name: String, portion: String, nutrients: Nutrients, uncertainty: String, id: UUID = UUID()) {
        self.id = id; self.name = name; self.portion = portion; self.nutrients = nutrients; self.uncertainty = uncertainty
    }
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        // The API schema omits IDs. Local serialization includes them for stable list identity.
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        name = try container.decode(String.self, forKey: .name)
        portion = try container.decode(String.self, forKey: .portion)
        nutrients = try container.decode(Nutrients.self, forKey: .nutrients)
        uncertainty = try container.decode(String.self, forKey: .uncertainty)
    }
    var isValid: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !portion.isEmpty && nutrients.isValid
    }
}

struct AnalysisResult: Codable, Sendable {
    var name: String
    var foods: [FoodEstimate]
    var totals: Nutrients
    var uncertainties: [String]
    var confidence: String

    static func decodeValidated(_ data: Data) throws -> Self {
        guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              Set(object.keys) == Set(["name", "foods", "totals", "uncertainties", "confidence"]),
              let foods = object["foods"] as? [[String: Any]],
              foods.allSatisfy({ food in
                  Set(food.keys) == Set(["name", "portion", "nutrients", "uncertainty"])
                  && validNutrientObject(food["nutrients"])
              }), validNutrientObject(object["totals"]) else { throw APIError.invalidResult }
        var value = try JSONDecoder().decode(Self.self, from: data)
        guard !value.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              (1...50).contains(value.foods.count), value.foods.allSatisfy(\.isValid),
              value.totals.isValid, ["low", "medium", "high"].contains(value.confidence) else { throw APIError.invalidResult }
        let sum = Nutrients.sum(value.foods.map(\.nutrients))
        guard sum.isValid else { throw APIError.invalidResult }
        if Nutrient.allCases.contains(where: { abs(sum[$0] - value.totals[$0]) > 1 }) {
            value.uncertainties.append("Die Gesamtwerte wurden aus den Einzelbestandteilen neu berechnet.")
        }
        value.totals = sum
        return value
    }

    private static func validNutrientObject(_ object: Any?) -> Bool {
        guard let dictionary = object as? [String: Any],
              Set(dictionary.keys) == Set(["calories_kcal", "protein_g", "carbohydrates_g", "fat_g", "fiber_g"]) else { return false }
        return dictionary.values.allSatisfy { value in
            guard let number = value as? NSNumber,
                  CFGetTypeID(number) != CFBooleanGetTypeID() else { return false }
            return number.doubleValue.isFinite && number.doubleValue >= 0 && number.doubleValue <= 1_000_000
        }
    }
}

enum AnalysisSchema {
    static var object: [String: Any] {
        let nutrientKeys = ["calories_kcal", "protein_g", "carbohydrates_g", "fat_g", "fiber_g"]
        let nutrients: [String: Any] = [
            "type": "object", "additionalProperties": false, "required": nutrientKeys,
            "properties": Dictionary(uniqueKeysWithValues: nutrientKeys.map { ($0, ["type": "number", "minimum": 0, "maximum": 1_000_000] as [String: Any]) })
        ]
        let food: [String: Any] = [
            "type": "object", "additionalProperties": false,
            "required": ["name", "portion", "nutrients", "uncertainty"],
            "properties": ["name": ["type": "string"], "portion": ["type": "string"],
                           "nutrients": nutrients, "uncertainty": ["type": "string"]]
        ]
        return [
            "type": "object", "additionalProperties": false,
            "required": ["name", "foods", "totals", "uncertainties", "confidence"],
            "properties": ["name": ["type": "string"],
                "foods": ["type": "array", "minItems": 1, "maxItems": 50, "items": food],
                "totals": nutrients,
                "uncertainties": ["type": "array", "items": ["type": "string"]],
                "confidence": ["type": "string", "enum": ["low", "medium", "high"]]]
        ]
    }
}
