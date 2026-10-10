import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.scenePhase) private var scenePhase
    @Query private var settings: [UserSettings]
    @Query private var meals: [Meal]
    @State private var key = ""
    @State private var revealKey = false
    @State private var keySaved = false
    @State private var references = Nutrients.zero
    @State private var enabledReferences: Set<Nutrient> = []
    @State private var invalidFields: Set<String> = []
    @State private var haptics = true
    @State private var speechLocale = "de-AT"
    @State private var message: String?
    @State private var errorMessage: String?
    @State private var testing = false
    @State private var testTask: Task<Void, Never>?
    @State private var confirmation: SettingsConfirmation?
    @State private var didLoad = false
    private var pendingSettings: Bool {
        guard didLoad, let setting = settings.first else { return false }
        return haptics != setting.haptics || speechLocale != setting.speechLocale || Nutrient.allCases.contains {
            (enabledReferences.contains($0) ? references[$0] : nil) != setting[$0]
        }
    }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("Deine Einstellungen").font(Theme.font(30, weight: .medium, relativeTo: .largeTitle))
                GlassCard {
                    VStack(alignment: .leading, spacing: 15) {
                        HStack {
                            SectionLabel(title: "OpenAI API-Schlüssel")
                            Image(systemName: "key.horizontal").foregroundStyle(Theme.mint)
                        }
                        Text(keySaved ? "Im Apple-Schlüsselbund gespeichert" : "Noch kein Schlüssel gespeichert").font(Theme.font(12)).foregroundStyle(Theme.secondary)
                        HStack {
                            Group {
                                if revealKey { TextField("sk-…", text: $key) }
                                else { SecureField("sk-…", text: $key) }
                            }.textInputAutocapitalization(.never).autocorrectionDisabled().inputStyle().privacySensitive()
                                .accessibilityLabel("OpenAI API-Schlüssel")
                            Button { revealKey.toggle() } label: {
                                Image(systemName: revealKey ? "eye.slash" : "eye").frame(width: 44, height: 44)
                            }.accessibilityLabel(revealKey ? "Schlüssel verbergen" : "Schlüssel anzeigen")
                        }.disabled(testing)
                        Button(keySaved ? "Schlüssel ersetzen" : "Schlüssel speichern") { saveKey() }
                            .buttonStyle(PrimaryButtonStyle()).disabled(key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || testing)
                        Button { testConnection() } label: {
                            if testing { HStack { ProgressView().tint(.white); Text("Verbindung wird geprüft …") } }
                            else { Label("Verbindung testen", systemImage: "antenna.radiowaves.left.and.right") }
                        }.buttonStyle(SecondaryButtonStyle()).disabled(testing || key.isEmpty)
                        Text("Der Test sendet eine kurze Anfrage an gpt-6-luna und kann geringe API-Kosten verursachen. Er prüft den hier eingegebenen Schlüssel, ohne ihn automatisch zu speichern.").font(Theme.font(11)).foregroundStyle(Theme.secondary)
                        if keySaved {
                            Button("Gespeicherten Schlüssel entfernen", role: .destructive) { confirmation = .key }
                                .font(Theme.font(13)).disabled(testing)
                        }
                    }
                }
                GlassCard {
                    VStack(alignment: .leading, spacing: 16) {
                        SectionLabel(title: "Tägliche Referenzwerte")
                        Text("Optional und frei wählbar. Ohne Referenzwert zeigen wir nur die erfasste Menge.").font(Theme.font(13)).foregroundStyle(Theme.secondary)
                        ForEach(Nutrient.allCases) { nutrient in
                            ReferenceField(nutrient: nutrient, value: Binding(
                                get: { enabledReferences.contains(nutrient) ? references[nutrient] : nil },
                                set: { value in
                                    if let value { enabledReferences.insert(nutrient); references[nutrient] = value }
                                    else { enabledReferences.remove(nutrient) }
                                }), invalidFields: $invalidFields)
                        }
                        Button("Referenzwerte zurücksetzen") { enabledReferences = []; invalidFields = [] }.font(Theme.font(13)).foregroundStyle(Theme.secondary)
                    }
                }
                GlassCard {
                    VStack(alignment: .leading, spacing: 18) {
                        SectionLabel(title: "App")
                        Toggle("Haptisches Feedback", isOn: $haptics).font(Theme.font(14)).tint(Theme.mint)
                        Picker("Diktiersprache", selection: $speechLocale) {
                            Text("Deutsch (Österreich)").tag("de-AT")
                            Text("Deutsch (Deutschland)").tag("de-DE")
                            Text("English").tag("en-US")
                        }.font(Theme.font(14)).pickerStyle(.menu)
                        Text("Diktate werden auf unterstützten iPhones lokal erkannt. Ernährung wird sachlich dokumentiert, ohne Bewertungen oder automatische Ernährungsempfehlungen.").font(Theme.font(11)).foregroundStyle(Theme.secondary)
                        Button("Einstellungen speichern") { saveSettings() }.buttonStyle(SecondaryButtonStyle()).disabled(!invalidFields.isEmpty)
                        if pendingSettings { Text("Ungespeicherte Änderungen").font(Theme.font(11)).foregroundStyle(Theme.orange) }
                    }
                }
                if let errorMessage { InlineError(message: errorMessage) }
                if let message { Label(message, systemImage: "checkmark.circle").font(Theme.font(14)).foregroundStyle(Theme.mint).accessibilityIdentifier("settings.status") }
                GlassCard {
                    VStack(alignment: .leading, spacing: 15) {
                        SectionLabel(title: "Deine Daten")
                        Text("\(meals.count) gespeicherte Mahlzeiten").font(Theme.font(14)).foregroundStyle(Theme.secondary)
                        Text("Mahlzeiten, Fotos und Einstellungen bleiben lokal. Keine Anmeldung, kein eigener Server, keine Cloud-Synchronisation. App-Daten sind von Geräte-Backups ausgeschlossen. Nur ausdrücklich gestartete KI-Anfragen senden Foto und Text an OpenAI. store: false verhindert die Speicherung als abrufbare API-Antwort; mögliche dienstseitige Aufbewahrung richtet sich nach OpenAIs API-Datenrichtlinien.")
                            .font(Theme.font(12)).foregroundStyle(Theme.secondary)
                        Link("OpenAI: Umgang mit API-Daten", destination: URL(string: "https://developers.openai.com/api/docs/guides/your-data")!).font(Theme.font(12)).foregroundStyle(Theme.mint)
                        Button("Alle Mahlzeiten & Fotos löschen", role: .destructive) { confirmation = .meals }.font(Theme.font(14))
                        Button("App vollständig zurücksetzen", role: .destructive) { confirmation = .reset }.font(Theme.font(14))
                    }
                }
                Text("Velox Nutrition · Version 1.0\nPrivat. Lokal. In deinem Tempo.").font(Theme.font(11)).foregroundStyle(Theme.secondary).multilineTextAlignment(.center).frame(maxWidth: .infinity)
            }.padding(22)
        }.scrollDismissesKeyboard(.interactively).appScreen().toolbar(.hidden, for: .navigationBar)
            .toolbar { ToolbarItemGroup(placement: .keyboard) { Spacer(); Button("Fertig") { UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil) } } }
            .onAppear { load() }
            .onDisappear { testTask?.cancel(); testing = false; revealKey = false }
            .onChange(of: scenePhase) { _, phase in if phase != .active { revealKey = false } }
            .confirmationDialog(confirmation?.title ?? "", isPresented: Binding(get: { confirmation != nil }, set: { if !$0 { confirmation = nil } }), titleVisibility: .visible) {
                if let action = confirmation { Button(action.button, role: .destructive) { perform(action); confirmation = nil } }
            }
    }
    private func load() {
        guard !didLoad else { return }
        do { key = try KeychainStore().read() ?? ""; keySaved = !key.isEmpty }
        catch { errorMessage = error.localizedDescription }
        if let setting = settings.first {
            for nutrient in Nutrient.allCases {
                if let value = setting[nutrient] { references[nutrient] = value; enabledReferences.insert(nutrient) }
            }
            haptics = setting.haptics; speechLocale = setting.speechLocale
        }
        didLoad = true
    }
    private func saveKey() {
        do { try KeychainStore().save(key); keySaved = true; errorMessage = nil; message = "Schlüssel im Apple-Schlüsselbund gespeichert." }
        catch { message = nil; errorMessage = error.localizedDescription }
    }
    private func testConnection() {
        guard !testing else { return }
        testing = true; errorMessage = nil; message = nil
        let submittedKey = key
        testTask = Task {
            do { try await OpenAIClient().testConnection(key: submittedKey); try Task.checkCancellation(); message = "Verbindung zu gpt-6-luna erfolgreich." }
            catch is CancellationError { }
            catch { if !Task.isCancelled { errorMessage = error.localizedDescription } }
            if !Task.isCancelled { testing = false; testTask = nil }
        }
    }
    private func saveSettings() {
        guard invalidFields.isEmpty, let setting = settings.first else { return }
        for nutrient in Nutrient.allCases { setting[nutrient] = enabledReferences.contains(nutrient) ? references[nutrient] : nil }
        setting.haptics = haptics; setting.speechLocale = speechLocale
        do { try context.save(); errorMessage = nil; message = "Einstellungen gespeichert." }
        catch { context.rollback(); message = nil; errorMessage = StoreError.save.localizedDescription }
    }
    private func perform(_ action: SettingsConfirmation) {
        testTask?.cancel(); testing = false; message = nil; errorMessage = nil
        do {
            switch action {
            case .key:
                try KeychainStore().remove(); key = ""; keySaved = false; revealKey = false
                message = "API-Schlüssel entfernt."
            case .meals:
                try MealStore(context: context).deleteAllMeals(); message = "Alle Mahlzeiten und Fotos gelöscht."
            case .reset:
                try MealStore(context: context).deleteAllMeals()
                try KeychainStore().remove(); key = ""; keySaved = false; revealKey = false
                enabledReferences = []; references = .zero; invalidFields = []; haptics = true; speechLocale = "de-AT"
                saveSettings()
                if errorMessage == nil { message = "App zurückgesetzt." }
            }
        } catch { errorMessage = error.localizedDescription }
    }
}

private enum SettingsConfirmation {
    case key, meals, reset
    var title: String {
        switch self {
        case .key: return "Gespeicherten API-Schlüssel entfernen?"
        case .meals: return "Alle Mahlzeiten und Fotos endgültig löschen?"
        case .reset: return "Alle Mahlzeiten, Fotos, Einstellungen und den API-Schlüssel endgültig löschen?"
        }
    }
    var button: String { self == .key ? "Schlüssel entfernen" : self == .meals ? "Alle Mahlzeiten löschen" : "Alles zurücksetzen" }
}
