import SwiftUI
import SwiftData

struct AnalysisComposerView: View {
    let mode: ComposerRoute
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @Query private var settings: [UserSettings]
    @State private var text = ""
    @State private var photo: Data?
    @State private var photoProcessing = false
    @State private var date = Date.now
    @State private var speech = SpeechService()
    @State private var dictatedPrefix = ""
    @State private var analyzing = false
    @State private var errorMessage: String?
    @State private var review: MealDraft?
    @State private var analysisTask: Task<Void, Never>?
    @State private var manual: MealDraft?
    @State private var showDiscard = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                Text(mode == .photo ? "Ein Foto.\nEin guter Überblick." : "Deine Mahlzeit.\nIn deinen Worten.")
                    .font(Theme.font(31, weight: .medium, relativeTo: .largeTitle))
                if mode == .photo { GlassCard { PhotoInput(jpeg: $photo, onProcessingChange: { photoProcessing = $0 }) }.disabled(analyzing) }
                GlassCard {
                    VStack(alignment: .leading, spacing: 14) {
                        HStack {
                            Text(mode == .photo ? "Details ergänzen" : "Was hast du gegessen?").font(Theme.font(17, weight: .medium))
                            Spacer()
                            Button { toggleSpeech() } label: {
                                Image(systemName: speech.isRecording ? "stop.fill" : "mic.fill").font(.system(size: 18))
                                    .foregroundStyle(speech.isRecording ? Theme.orange : Theme.mint)
                                    .frame(width: 44, height: 44).background(.white.opacity(0.08), in: Circle())
                            }.disabled(analyzing || speech.isStarting).accessibilityLabel(speech.isRecording ? "Diktat beenden" : "Mahlzeit diktieren")
                        }
                        TextField(mode == .photo ? "Zum Beispiel: 250 g Steak, Kartoffeln mit Butter gebraten …" : "Zum Beispiel: zwei Spiegeleier, drei Scheiben Speck und eine Semmel …", text: $text, axis: .vertical)
                            .lineLimit(5...10).inputStyle().disabled(analyzing || speech.isRecording).accessibilityIdentifier("analysis.description")
                        if speech.isStarting { ProgressView("Spracherkennung starten …") }
                        if speech.isRecording { Label("Ich höre zu … Tippe auf Stopp, um den Text zu bearbeiten.", systemImage: "waveform").font(Theme.font(12)).foregroundStyle(Theme.mint) }
                        if let message = speech.errorMessage { InlineError(message: message) }
                        DatePicker("Datum & Uhrzeit", selection: $date).font(Theme.font(14)).disabled(analyzing)
                    }
                }
                GlassCard {
                    Label("Mit „Mit KI analysieren“ sendest du diese Beschreibung und ein gewähltes Foto an OpenAI. Die Verarbeitung erfolgt extern und kann API-Kosten verursachen. Gespeichert wird erst nach deiner Bestätigung.", systemImage: "lock.shield")
                        .font(Theme.font(12)).foregroundStyle(Theme.secondary)
                }
                if let errorMessage { InlineError(message: errorMessage) }
                if analyzing {
                    VStack(spacing: 14) {
                        ProgressView().tint(Theme.mint)
                        Text("Lebensmittel & Mengen werden geschätzt …").font(Theme.font(14)).foregroundStyle(Theme.secondary)
                        Button("Analyse abbrechen") { cancelAnalysis() }.font(Theme.font(14))
                    }.frame(maxWidth: .infinity).padding(20)
                } else {
                    Button { analyze() } label: { Label(errorMessage == nil ? "Mit KI analysieren" : "Analyse erneut starten", systemImage: "sparkles") }
                        .buttonStyle(PrimaryButtonStyle()).disabled(!canAnalyze || photoProcessing || speech.isRecording || speech.isStarting)
                        .accessibilityIdentifier("analysis.start")
                    Button("Manuell erfassen") {
                        var draft = MealDraft(date: date); draft.notes = text; draft.photoJPEG = photo; draft.photoChanged = photo != nil
                        manual = draft
                    }.buttonStyle(SecondaryButtonStyle()).disabled(photoProcessing)
                }
            }.padding(22)
        }.scrollDismissesKeyboard(.interactively).appScreen()
            .navigationTitle(mode == .photo ? "Fotoanalyse" : "Textanalyse").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Schließen") { if text.isEmpty && photo == nil { dismiss() } else { showDiscard = true } } } }
            .interactiveDismissDisabled(analyzing || !text.isEmpty || photo != nil)
            .confirmationDialog("Ungespeicherte Angaben verwerfen?", isPresented: $showDiscard, titleVisibility: .visible) {
                Button("Verwerfen", role: .destructive) { cancelAnalysis(); dismiss() }
            }
            .sheet(item: $review) { draft in
                NavigationStack {
                    MealEditorView(draft: draft, onSaved: { review = nil; dismiss() }, onReanalyze: { review = nil; analyze() })
                }.preferredColorScheme(.dark)
            }
            .sheet(item: $manual) { draft in
                NavigationStack { MealEditorView(draft: draft, onSaved: { manual = nil; dismiss() }) }.preferredColorScheme(.dark)
            }
            .onChange(of: speech.transcript) { _, value in
                if !value.isEmpty { text = dictatedPrefix.isEmpty ? value : dictatedPrefix + " " + value }
            }
            .onChange(of: scenePhase) { _, phase in if phase != .active { speech.stop() } }
            .onDisappear { speech.stop(); analysisTask?.cancel() }
    }
    private var canAnalyze: Bool { mode == .photo ? photo != nil : !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    private func toggleSpeech() {
        if speech.isRecording { speech.stop() }
        else {
            dictatedPrefix = text.trimmingCharacters(in: .whitespacesAndNewlines)
            Task { await speech.start(locale: settings.first?.speechLocale ?? "de-AT") }
        }
    }
    private func cancelAnalysis() { analysisTask?.cancel(); analysisTask = nil; analyzing = false }
    private func analyze() {
        guard !analyzing, !photoProcessing, canAnalyze else { return }
        speech.stop(); errorMessage = nil
        let key: String
        do {
            guard let saved = try KeychainStore().read(), !saved.isEmpty else { throw APIError.missingKey }
            key = saved
        } catch { errorMessage = error.localizedDescription; return }
        analyzing = true
        let submittedText = text; let submittedPhoto = photo; let submittedDate = date
        analysisTask = Task {
            do {
                let result = try await OpenAIClient().analyze(text: submittedText, imageJPEG: submittedPhoto, key: key)
                try Task.checkCancellation()
                review = MealDraft(result: result, date: submittedDate, notes: submittedText, photo: submittedPhoto)
                if settings.first?.haptics == true { UINotificationFeedbackGenerator().notificationOccurred(.success) }
            } catch is CancellationError { }
            catch { if !Task.isCancelled { errorMessage = error.localizedDescription } }
            if !Task.isCancelled { analyzing = false; analysisTask = nil }
        }
    }
}
