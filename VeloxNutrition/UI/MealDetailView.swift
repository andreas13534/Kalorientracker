import SwiftUI
import SwiftData

struct MealDetailView: View {
    let meal: Meal
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var editor: MealDraft?
    @State private var confirmDelete = false
    @State private var errorMessage: String?
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 23) {
                if let filename = meal.photoFilename { MealPhoto(filename: filename, size: 260).frame(maxWidth: .infinity) }
                Text(meal.name).font(Theme.font(32, weight: .medium, relativeTo: .largeTitle))
                HStack {
                    Text(meal.date.formatted(.dateTime.day().month(.wide).year().hour().minute()))
                    Spacer()
                    Text(meal.source == "manual" ? "Manuell" : "KI-Schätzung")
                }.font(Theme.font(12)).foregroundStyle(Theme.secondary)
                GlassCard { NutrientRows(nutrients: meal.nutrients) }
                if !meal.notes.isEmpty {
                    GlassCard {
                        VStack(alignment: .leading, spacing: 12) {
                            SectionLabel(title: "Beschreibung")
                            Text(meal.notes).font(Theme.font(14)).foregroundStyle(Theme.secondary)
                        }
                    }
                }
                if !meal.foods.isEmpty {
                    SectionLabel(title: "Lebensmittel & Mengen")
                    ForEach(meal.foods) { food in
                        GlassCard {
                            VStack(alignment: .leading, spacing: 12) {
                                Text(food.name).font(Theme.font(17, weight: .medium))
                                Text(food.portion).font(Theme.font(13)).foregroundStyle(Theme.secondary)
                                Text("\(NutritionNumber.display(food.nutrients.calories)) kcal").font(Theme.font(18))
                                FlowMacros(nutrients: food.nutrients)
                                if !food.uncertainty.isEmpty { Text(food.uncertainty).font(Theme.font(12)).foregroundStyle(Theme.secondary) }
                            }
                        }
                    }
                }
                if !meal.uncertaintyNotes.isEmpty {
                    GlassCard {
                        VStack(alignment: .leading, spacing: 12) {
                            SectionLabel(title: "Schätzungen & Annahmen")
                            Text(meal.uncertaintyNotes).font(Theme.font(14)).foregroundStyle(Theme.secondary)
                        }
                    }
                }
                if let errorMessage { InlineError(message: errorMessage) }
                Button { editor = MealDraft(meal: meal) } label: { Label("Mahlzeit bearbeiten", systemImage: "pencil") }.buttonStyle(PrimaryButtonStyle())
                Button("Mahlzeit löschen", role: .destructive) { confirmDelete = true }.buttonStyle(SecondaryButtonStyle())
            }.padding(22)
        }.appScreen().navigationTitle("Mahlzeit").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Fertig") { dismiss() } } }
            .sheet(item: $editor) { draft in NavigationStack { MealEditorView(draft: draft) }.preferredColorScheme(.dark) }
            .confirmationDialog("Diese Mahlzeit und ihr Foto endgültig löschen?", isPresented: $confirmDelete, titleVisibility: .visible) {
                Button("Mahlzeit löschen", role: .destructive) {
                    do { try MealStore(context: context).delete(meal); dismiss() }
                    catch { errorMessage = error.localizedDescription }
                }
            }
    }
}
