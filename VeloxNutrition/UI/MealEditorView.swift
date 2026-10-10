import SwiftUI
import SwiftData

struct MealEditorView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State var draft: MealDraft
    var onSaved: (() -> Void)?
    var onReanalyze: (() -> Void)?
    @State private var invalidFields: Set<String> = []
    @State private var errorMessage: String?
    @State private var saving = false
    @State private var showDiscard = false
    @State private var dirty = false
    @State private var photoRemoved = false
    @State private var photoProcessing = false
    @FocusState private var focused: Bool
    private var isReview: Bool { draft.editingMeal == nil && draft.source != "manual" }
    private var title: String { isReview ? "Ergebnis prüfen" : draft.editingMeal == nil ? "Manuell erfassen" : "Mahlzeit bearbeiten" }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                if isReview {
                    GlassCard {
                        VStack(alignment: .leading, spacing: 9) {
                            Label("Deine Bestätigung zählt", systemImage: "checkmark.shield").font(Theme.font(17, weight: .medium)).foregroundStyle(Theme.mint)
                            Text("Das sind Schätzungen. Prüfe Lebensmittel, Mengen und Nährwerte. Erst mit „Mahlzeit speichern“ wird ein Eintrag angelegt.").font(Theme.font(14)).foregroundStyle(Theme.secondary)
                        }
                    }
                }
                GlassCard {
                    VStack(alignment: .leading, spacing: 15) {
                        Text("Mahlzeit").font(Theme.font(18, weight: .medium))
                        TextField("Name des Gerichts", text: $draft.name).inputStyle().focused($focused).accessibilityIdentifier("meal.name")
                        DatePicker("Datum & Uhrzeit", selection: $draft.date).font(Theme.font(14)).datePickerStyle(.compact)
                        TextField("Beschreibung (optional)", text: $draft.notes, axis: .vertical).lineLimit(3...6).inputStyle().focused($focused)
                    }
                }
                GlassCard {
                    PhotoInput(jpeg: $draft.photoJPEG, filename: photoRemoved ? nil : draft.photoFilename, changed: {
                        draft.photoChanged = true; photoRemoved = draft.photoJPEG == nil; dirty = true
                    }, onProcessingChange: { photoProcessing = $0 })
                }
                if draft.source != "manual" || !draft.foods.isEmpty {
                    SectionLabel(title: "Erkannte Lebensmittel")
                    ForEach($draft.foods) { $food in
                        GlassCard {
                            VStack(alignment: .leading, spacing: 12) {
                                TextField("Lebensmittel", text: $food.name).inputStyle()
                                TextField("Geschätzte Menge", text: $food.portion).inputStyle()
                                NutrientEditor(nutrients: $food.nutrients, invalidFields: $invalidFields, prefix: food.id.uuidString)
                                TextField("Unsicherheit / Annahme", text: $food.uncertainty, axis: .vertical).inputStyle()
                                Button("Bestandteil entfernen", role: .destructive) { remove(food.id) }.font(Theme.font(12))
                            }
                        }
                    }
                    Button { draft.foods.append(FoodEstimate(name: "", portion: "", nutrients: .zero, uncertainty: "")) } label: { Label("Bestandteil ergänzen", systemImage: "plus") }
                        .buttonStyle(SecondaryButtonStyle())
                }
                GlassCard {
                    VStack(alignment: .leading, spacing: 16) {
                        SectionLabel(title: "Gesamtwerte")
                        NutrientEditor(nutrients: $draft.nutrients, invalidFields: $invalidFields)
                        if !draft.foods.isEmpty {
                            Text("Änderungen an Einzelwerten berechnen die Summe neu. Du kannst die Gesamtwerte anschließend separat korrigieren.").font(Theme.font(11)).foregroundStyle(Theme.secondary)
                            Button("Summe aus Bestandteilen übernehmen") { draft.nutrients = Nutrients.sum(draft.foods.map(\.nutrients)) }
                                .font(Theme.font(12)).foregroundStyle(Theme.mint)
                        }
                    }
                }
                if draft.source != "manual" {
                    GlassCard {
                        VStack(alignment: .leading, spacing: 12) {
                            Label("Schätzungen & Annahmen", systemImage: "info.circle").font(Theme.font(16, weight: .medium))
                            TextField("Unsicherheiten", text: $draft.uncertaintyNotes, axis: .vertical).lineLimit(3...8).inputStyle()
                        }
                    }
                }
                if let errorMessage { InlineError(message: errorMessage) }
                Button { save() } label: { Label(saving ? "Speichern …" : "Mahlzeit speichern", systemImage: "checkmark") }
                    .buttonStyle(PrimaryButtonStyle()).disabled(saving || photoProcessing || !draft.isValid || !invalidFields.isEmpty)
                    .accessibilityIdentifier("meal.save")
                if let onReanalyze {
                    Button("Erneut analysieren", action: onReanalyze).buttonStyle(SecondaryButtonStyle())
                    Text("Eine neue Analyse verwendet das ursprüngliche Foto und die ursprüngliche Beschreibung.").font(Theme.font(11)).foregroundStyle(Theme.secondary)
                }
            }.padding(22)
        }.scrollDismissesKeyboard(.interactively).appScreen().navigationTitle(title).navigationBarTitleDisplayMode(.inline)
            .interactiveDismissDisabled(dirty || isReview)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Abbrechen") { if dirty || isReview { showDiscard = true } else { dismiss() } } }
                ToolbarItemGroup(placement: .keyboard) { Spacer(); Button("Fertig") { focused = false; UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil) } }
            }
            .confirmationDialog("Ungespeicherte Angaben verwerfen?", isPresented: $showDiscard, titleVisibility: .visible) {
                Button("Verwerfen", role: .destructive) { dismiss() }
            }
            .onChange(of: draft.name) { _, _ in dirty = true }
            .onChange(of: draft.date) { _, _ in dirty = true }
            .onChange(of: draft.notes) { _, _ in dirty = true }
            .onChange(of: draft.nutrients) { _, _ in dirty = true }
            .onChange(of: invalidFields) { _, fields in if !fields.isEmpty { dirty = true } }
            .onChange(of: draft.uncertaintyNotes) { _, _ in dirty = true }
            .onChange(of: draft.foods) { old, new in
                dirty = true
                if old.map(\.nutrients) != new.map(\.nutrients) { draft.nutrients = Nutrients.sum(new.map(\.nutrients)) }
            }
    }
    private func remove(_ id: UUID) {
        invalidFields = invalidFields.filter { !$0.hasPrefix(id.uuidString) }
        draft.foods.removeAll { $0.id == id }
    }
    private func save() {
        guard !saving, !photoProcessing, invalidFields.isEmpty, draft.isValid else { return }
        saving = true
        do {
            try MealStore(context: context).save(draft)
            dirty = false; dismiss(); onSaved?()
        } catch { errorMessage = error.localizedDescription; saving = false }
    }
}
