import SwiftUI
import SwiftData

@main
struct VeloxNutritionApp: App {
    @State private var container: ModelContainer?
    @State private var startupError: String?
    var body: some Scene {
        WindowGroup {
            Group {
                if let container {
                    RootView().modelContainer(container)
                } else {
                    ZStack {
                        AppBackground()
                        VStack(spacing: 20) {
                            Image(systemName: "leaf.fill").font(.system(size: 42)).foregroundStyle(Theme.mint)
                            Text(startupError == nil ? "Velox Nutrition" : "Speicher nicht verfügbar").font(Theme.font(26, weight: .semibold))
                            if let startupError {
                                Text(startupError).foregroundStyle(Theme.secondary).multilineTextAlignment(.center)
                                Button("Erneut versuchen", action: load).buttonStyle(PrimaryButtonStyle())
                            } else { ProgressView().tint(.white) }
                        }.padding(28)
                    }.task { if container == nil && startupError == nil { load() } }
                }
            }.preferredColorScheme(.dark).tint(Theme.mint)
        }
    }
    @MainActor private func load() {
        do {
            try LocalStorage.prepare(LocalStorage.directory)
            let schema = Schema([Meal.self, UserSettings.self])
            let config = ModelConfiguration("Nutrition", schema: schema,
                url: LocalStorage.directory.appendingPathComponent("Nutrition.store"), cloudKitDatabase: .none)
            let store = try ModelContainer(for: schema, configurations: [config])
            store.mainContext.autosaveEnabled = false
            if try store.mainContext.fetch(FetchDescriptor<UserSettings>()).isEmpty {
                store.mainContext.insert(UserSettings()); try store.mainContext.save()
            }
            try? MealStore(context: store.mainContext).cleanup()
            container = store; startupError = nil
        } catch {
            startupError = "Die lokale Datenbank konnte nicht geöffnet werden. Deine vorhandenen Daten werden nicht überschrieben. Entsperre das iPhone und prüfe den freien Speicherplatz."
        }
    }
}
