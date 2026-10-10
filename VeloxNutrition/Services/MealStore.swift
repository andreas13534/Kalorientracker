import SwiftData
import Foundation

@MainActor
struct MealStore {
    let context: ModelContext
    var photos = PhotoStore()

    @discardableResult
    func save(_ draft: MealDraft) throws -> Meal {
        guard draft.isValid else { throw StoreError.invalidMeal }
        let encodedFoods = try JSONEncoder().encode(draft.foods)
        let oldPhoto = draft.editingMeal?.photoFilename
        var newPhoto = draft.photoFilename
        if draft.photoChanged { newPhoto = try draft.photoJPEG.map { try photos.save($0) } }
        let meal = draft.editingMeal ?? Meal(name: draft.name)
        if draft.editingMeal == nil { context.insert(meal) }
        meal.name = draft.name.trimmingCharacters(in: .whitespacesAndNewlines)
        meal.date = draft.date; meal.notes = draft.notes; meal.nutrients = draft.nutrients
        meal.foodsData = encodedFoods; meal.uncertaintyNotes = draft.uncertaintyNotes
        meal.source = draft.source; meal.photoFilename = newPhoto
        do { try context.save() }
        catch {
            context.rollback()
            if draft.photoChanged && newPhoto != oldPhoto { try? photos.remove(newPhoto) }
            throw StoreError.save
        }
        // Database commit comes first. Interrupted cleanup is retried at the next launch.
        if oldPhoto != newPhoto { try? photos.remove(oldPhoto) }
        return meal
    }
    func delete(_ meal: Meal) throws {
        let filename = meal.photoFilename
        context.delete(meal)
        do { try context.save() } catch { context.rollback(); throw StoreError.save }
        try? photos.remove(filename)
    }
    func deleteAllMeals() throws {
        let meals = try context.fetch(FetchDescriptor<Meal>())
        for meal in meals { context.delete(meal) }
        do { try context.save() } catch { context.rollback(); throw StoreError.save }
        try photos.cleanOrphans(keeping: [])
    }
    func cleanup() throws {
        let meals = try context.fetch(FetchDescriptor<Meal>())
        try photos.cleanOrphans(keeping: Set(meals.compactMap(\.photoFilename)))
    }
}
