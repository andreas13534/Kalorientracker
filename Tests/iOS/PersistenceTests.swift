import XCTest
import SwiftData
import UIKit
@testable import VeloxNutrition

@MainActor
final class PersistenceTests: XCTestCase {
    private func container(url: URL? = nil) throws -> ModelContainer {
        let schema = Schema([Meal.self, UserSettings.self])
        let config: ModelConfiguration
        if let url { config = ModelConfiguration("Test", schema: schema, url: url, cloudKitDatabase: .none) }
        else { config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none) }
        return try ModelContainer(for: schema, configurations: [config])
    }
    func testSaveEditMoveDayAndDelete() throws {
        let container = try container(); let context = container.mainContext; context.autosaveEnabled = false
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: folder) }
        let store = MealStore(context: context, photos: PhotoStore(directory: folder))
        var draft = MealDraft(); draft.name = "Mittagessen"; draft.nutrients = Nutrients(calories: 450, protein: 30, carbohydrates: 40, fat: 18, fiber: 6)
        let meal = try store.save(draft)
        XCTAssertEqual(try context.fetch(FetchDescriptor<Meal>()).count, 1)
        var edit = MealDraft(meal: meal); edit.nutrients.protein = 40
        edit.date = Calendar.current.date(byAdding: .day, value: -1, to: draft.date)!
        try store.save(edit)
        XCTAssertEqual(meal.protein, 40)
        XCTAssertFalse(DayRange.contains(meal.date, in: draft.date))
        try store.delete(meal)
        XCTAssertTrue(try context.fetch(FetchDescriptor<Meal>()).isEmpty)
    }
    func testDiskStorePersistsAllValuesAndReferences() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let url = folder.appendingPathComponent("Nutrition.store")
        try autoreleasepool {
            let container = try container(url: url)
            let meal = Meal(name: "Abendessen", nutrients: Nutrients(calories: 700, protein: 44, carbohydrates: 90, fat: 18, fiber: 8), notes: "selbst gekocht")
            let setting = UserSettings(); setting.protein = 100
            container.mainContext.insert(meal); container.mainContext.insert(setting); try container.mainContext.save()
        }
        let reopened = try container(url: url)
        let meal = try XCTUnwrap(reopened.mainContext.fetch(FetchDescriptor<Meal>()).first)
        XCTAssertEqual(meal.name, "Abendessen"); XCTAssertEqual(meal.nutrients.fiber, 8); XCTAssertEqual(meal.notes, "selbst gekocht")
        XCTAssertEqual(try reopened.mainContext.fetch(FetchDescriptor<UserSettings>()).first?.protein, 100)
    }
    func testPhotoReplacementRemovalAndOrphanCleanup() throws {
        let container = try container(); let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: folder) }
        let photos = PhotoStore(directory: folder); let store = MealStore(context: container.mainContext, photos: photos)
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 2000, height: 1000))
        let data = renderer.jpegData(withCompressionQuality: 1) { ctx in UIColor.green.setFill(); ctx.fill(CGRect(x: 0, y: 0, width: 2000, height: 1000)) }
        let jpeg = try PhotoStore.compress(data)
        let image = try XCTUnwrap(UIImage(data: jpeg)); XCTAssertLessThanOrEqual(max(image.size.width, image.size.height), 1600)
        var draft = MealDraft(); draft.name = "Foto"; draft.photoJPEG = jpeg; draft.photoChanged = true
        let meal = try store.save(draft); let first = try XCTUnwrap(meal.photoFilename)
        XCTAssertNotNil(photos.read(first))
        var edit = MealDraft(meal: meal); edit.photoChanged = true; edit.photoJPEG = jpeg
        try store.save(edit); XCTAssertNil(photos.read(first)); XCTAssertNotNil(photos.read(meal.photoFilename))
        let orphan = try photos.save(jpeg); try store.cleanup(); XCTAssertNil(photos.read(orphan))
        try store.deleteAllMeals(); XCTAssertTrue(try container.mainContext.fetch(FetchDescriptor<Meal>()).isEmpty)
        XCTAssertTrue(try FileManager.default.contentsOfDirectory(atPath: folder.path).isEmpty)
        XCTAssertNil(photos.url("../outside.jpg"))
    }
    func testReviewDraftDoesNotCreateMealBeforeConfirmation() throws {
        let container = try container()
        let food = FoodEstimate(name: "Brot", portion: "50 g", nutrients: Nutrients(calories: 120), uncertainty: "Sorte geschätzt")
        let result = AnalysisResult(name: "Brot", foods: [food], totals: food.nutrients, uncertainties: [], confidence: "medium")
        let draft = MealDraft(result: result, date: .now, notes: "Brot", photo: nil)
        XCTAssertTrue(try container.mainContext.fetch(FetchDescriptor<Meal>()).isEmpty)
        XCTAssertTrue(draft.isValid)
        try MealStore(context: container.mainContext).save(draft)
        XCTAssertEqual(try container.mainContext.fetch(FetchDescriptor<Meal>()).count, 1)
    }
}
