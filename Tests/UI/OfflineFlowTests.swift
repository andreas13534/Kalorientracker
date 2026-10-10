import XCTest

final class OfflineFlowTests: XCTestCase {
    func testManualMealAndNavigationWithoutAPIKey() {
        let app = XCUIApplication(); app.launch()
        let mealName = "Offline-Test-" + String(UUID().uuidString.prefix(8))
        let addMeal = app.buttons["add.manual"]
        XCTAssertTrue(addMeal.waitForExistence(timeout: 10))
        if !addMeal.isHittable { app.swipeUp() }
        addMeal.tap()
        let name = app.textFields["meal.name"]
        XCTAssertTrue(name.waitForExistence(timeout: 5)); name.tap(); name.typeText(mealName)
        let calories = app.textFields["value.total.calories"]
        app.swipeUp(); XCTAssertTrue(calories.waitForExistence(timeout: 5))
        calories.tap()
        let existing = calories.value as? String ?? ""
        calories.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: existing.count) + "250")
        if app.buttons["Fertig"].exists { app.buttons["Fertig"].firstMatch.tap() }
        app.swipeUp()
        let save = app.buttons["meal.save"]; XCTAssertTrue(save.waitForExistence(timeout: 5)); save.tap()
        let meal = app.buttons.matching(NSPredicate(format: "identifier == %@ AND label CONTAINS %@", "meal.row", mealName)).firstMatch
        XCTAssertTrue(meal.waitForExistence(timeout: 5))
        let dashboard = XCTAttachment(screenshot: app.screenshot()); dashboard.name = "Dashboard"; dashboard.lifetime = .keepAlways; add(dashboard)
        app.buttons["tab.history"].tap()
        XCTAssertTrue(meal.waitForExistence(timeout: 5))
        app.buttons["tab.settings"].tap()
        XCTAssertTrue(app.staticTexts["OpenAI API-Schlüssel"].waitForExistence(timeout: 5))
        let screenshot = XCTAttachment(screenshot: app.screenshot()); screenshot.name = "Einstellungen"; screenshot.lifetime = .keepAlways; add(screenshot)
    }
}
