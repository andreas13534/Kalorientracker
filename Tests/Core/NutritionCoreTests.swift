import XCTest
#if SWIFT_PACKAGE
@testable import NutritionCore
#else
@testable import VeloxNutrition
#endif

final class NutritionCoreTests: XCTestCase {
    func testAllFiveTotalsAndOptionalProgress() {
        let a = Nutrients(calories: 410, protein: 22, carbohydrates: 32, fat: 17, fiber: 4)
        let b = Nutrients(calories: 220, protein: 18, carbohydrates: 16, fat: 7, fiber: 3)
        let total = Nutrients.sum([a, b])
        XCTAssertEqual(total, Nutrients(calories: 630, protein: 40, carbohydrates: 48, fat: 24, fiber: 7))
        XCTAssertNil(total.progress(for: .calories, reference: nil))
        XCTAssertNil(total.progress(for: .calories, reference: 0))
        XCTAssertEqual(total.progress(for: .protein, reference: 80), 0.5)
        XCTAssertEqual(total.progress(for: .protein, reference: 20), 1)
    }
    func testDecimalCommaAndInvalidInput() {
        XCTAssertEqual(NutritionNumber.parse(" 12,5 "), 12.5)
        XCTAssertEqual(NutritionNumber.parse("0"), 0)
        for input in ["", "-1", "nan", "inf", "1,2,3", "1.000,2", "1000001"] { XCTAssertNil(NutritionNumber.parse(input), input) }
        XCTAssertFalse(Nutrients(calories: .infinity).isValid)
        XCTAssertFalse(Nutrients(protein: -1).isValid)
    }
    func testCalendarBoundariesIncludingDST() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Vienna")!
        let date = calendar.date(from: DateComponents(year: 2026, month: 3, day: 29, hour: 12))!
        let range = DayRange.interval(for: date, calendar: calendar)
        XCTAssertEqual(range.duration, 23 * 3600)
        XCTAssertTrue(DayRange.contains(range.start, in: date, calendar: calendar))
        XCTAssertFalse(DayRange.contains(range.end, in: date, calendar: calendar))
        let autumn = calendar.date(from: DateComponents(year: 2026, month: 10, day: 25, hour: 12))!
        XCTAssertEqual(DayRange.interval(for: autumn, calendar: calendar).duration, 25 * 3600)
    }
    private func validResult() -> [String: Any] {
        let nutrients: [String: Any] = ["calories_kcal": 250, "protein_g": 12.5, "carbohydrates_g": 23, "fat_g": 11, "fiber_g": 4]
        return ["name": "Frühstück", "foods": [["name": "Ei mit Brot", "portion": "1 Portion", "nutrients": nutrients, "uncertainty": "Buttermenge geschätzt"]],
                "totals": nutrients, "uncertainties": ["Menge geschätzt"], "confidence": "medium"]
    }
    private func data(_ object: Any) throws -> Data { try JSONSerialization.data(withJSONObject: object) }

    func testResultValidationAndRecalculation() throws {
        var object = validResult()
        var totals = object["totals"] as! [String: Any]; totals["calories_kcal"] = 999; object["totals"] = totals
        let result = try AnalysisResult.decodeValidated(data(object))
        XCTAssertEqual(result.totals.calories, 250)
        XCTAssertEqual(result.totals.protein, 12.5)
        XCTAssertTrue(result.uncertainties.contains { $0.contains("neu berechnet") })
    }
    func testLocalFoodSerializationKeepsIdentity() throws {
        let food = FoodEstimate(name: "Brot", portion: "50 g", nutrients: Nutrients(calories: 120), uncertainty: "Sorte geschätzt")
        let data = try JSONEncoder().encode([food])
        let restored = try JSONDecoder().decode([FoodEstimate].self, from: data)
        XCTAssertEqual(restored.first?.id, food.id)
        XCTAssertEqual(restored.first?.nutrients, food.nutrients)
    }
    func testRejectsUnexpectedMissingNegativeAndBooleanValues() throws {
        var extra = validResult(); extra["unexpected"] = true
        XCTAssertThrowsError(try AnalysisResult.decodeValidated(data(extra)))
        var missing = validResult(); missing.removeValue(forKey: "foods")
        XCTAssertThrowsError(try AnalysisResult.decodeValidated(data(missing)))
        var empty = validResult(); empty["foods"] = []
        XCTAssertThrowsError(try AnalysisResult.decodeValidated(data(empty)))
        for invalid: Any in [-1, true, "12", 1_000_001] {
            var object = validResult(); var totals = object["totals"] as! [String: Any]
            totals["protein_g"] = invalid; object["totals"] = totals
            XCTAssertThrowsError(try AnalysisResult.decodeValidated(data(object)))
        }
    }
    func testResponsesEnvelopeIgnoresReasoningAndHandlesRefusal() throws {
        let text = String(data: try data(validResult()), encoding: .utf8)!
        let response: [String: Any] = ["status": "completed", "output": [
            ["type": "reasoning", "summary": []],
            ["type": "message", "content": [["type": "output_text", "text": text]]]
        ]]
        XCTAssertEqual(try OpenAIClient.parseResponse(data(response)).name, "Frühstück")
        XCTAssertThrowsError(try OpenAIClient.parseResponse(data(["status": "incomplete", "output": []]))) { XCTAssertEqual($0 as? APIError, .incomplete) }
        let refusal: [String: Any] = ["status": "completed", "output": [["type": "message", "content": [["type": "refusal", "refusal": "no"]]]]]
        XCTAssertThrowsError(try OpenAIClient.parseResponse(data(refusal))) { XCTAssertEqual($0 as? APIError, .refused) }
    }
    func testRequestUsesResponsesVisionAndStrictSchemaWithoutStorage() throws {
        let jpeg = Data([0xFF, 0xD8, 0xFF, 0xD9])
        let body = try XCTUnwrap(JSONSerialization.jsonObject(with: OpenAIClient.requestBody(text: "250 g Steak", imageJPEG: jpeg)) as? [String: Any])
        XCTAssertEqual(body["model"] as? String, "gpt-6-luna")
        XCTAssertEqual(body["store"] as? Bool, false)
        let input = try XCTUnwrap(body["input"] as? [[String: Any]])
        let content = try XCTUnwrap(input.first?["content"] as? [[String: Any]])
        XCTAssertEqual(content.count, 2)
        XCTAssertEqual(content[1]["image_url"] as? String, "data:image/jpeg;base64,\(jpeg.base64EncodedString())")
        let text = body["text"] as! [String: Any]; let format = text["format"] as! [String: Any]
        XCTAssertEqual(format["type"] as? String, "json_schema")
        XCTAssertEqual(format["strict"] as? Bool, true)
        XCTAssertThrowsError(try OpenAIClient.requestBody(text: " ", imageJPEG: nil))
        XCTAssertThrowsError(try OpenAIClient.requestBody(text: "Foto", imageJPEG: Data(repeating: 0, count: 4_000_001)))
    }
}
