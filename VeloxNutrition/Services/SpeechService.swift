import AVFoundation
import Speech
import Observation

@MainActor
@Observable
final class SpeechService {
    var isRecording = false
    var isStarting = false
    var transcript = ""
    var errorMessage: String?
    private var engine: AVAudioEngine?
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?
    private var generation = UUID()

    func start(locale: String) async {
        guard !isRecording && !isStarting else { return }
        isStarting = true; errorMessage = nil; transcript = ""
        let token = UUID(); generation = token
        defer { if generation == token { isStarting = false } }
        let speechPermission = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { continuation.resume(returning: $0) }
        }
        guard generation == token else { return }
        guard speechPermission == .authorized else {
            errorMessage = "Erlaube die Spracherkennung in den iPhone-Einstellungen für Velox Nutrition."; return
        }
        let microphone = await withCheckedContinuation { continuation in
            AVAudioSession.sharedInstance().requestRecordPermission { continuation.resume(returning: $0) }
        }
        guard generation == token else { return }
        guard microphone else { errorMessage = "Erlaube den Mikrofonzugriff in den iPhone-Einstellungen."; return }
        guard let recognizer = SFSpeechRecognizer(locale: Locale(identifier: locale)), recognizer.supportsOnDeviceRecognition else {
            errorMessage = "Lokale Spracherkennung ist für diese Sprache auf diesem iPhone nicht verfügbar. Wähle Deutsch (Deutschland) oder tippe den Text ein."; return
        }
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.record, mode: .measurement, options: .duckOthers)
            try session.setActive(true, options: .notifyOthersOnDeactivation)
            let audioEngine = AVAudioEngine()
            let speechRequest = SFSpeechAudioBufferRecognitionRequest()
            speechRequest.requiresOnDeviceRecognition = true
            speechRequest.shouldReportPartialResults = true
            let input = audioEngine.inputNode
            let format = input.outputFormat(forBus: 0)
            guard format.sampleRate > 0, format.channelCount > 0 else { throw StoreError.photo }
            input.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in speechRequest.append(buffer) }
            engine = audioEngine; request = speechRequest
            task = recognizer.recognitionTask(with: speechRequest) { [weak self] result, error in
                let text = result?.bestTranscription.formattedString
                let final = result?.isFinal ?? false
                let failed = error != nil
                Task { @MainActor in
                    guard let self, self.generation == token else { return }
                    if let text { self.transcript = text }
                    if failed || final {
                        if failed && self.isRecording { self.errorMessage = "Die Aufnahme wurde beendet. Du kannst den erkannten Text bearbeiten oder erneut diktieren." }
                        self.stop()
                    }
                }
            }
            audioEngine.prepare(); try audioEngine.start(); isRecording = true
        } catch {
            stop(); errorMessage = "Das Mikrofon konnte nicht gestartet werden. Prüfe die Berechtigung und versuche es erneut."
        }
    }
    func stop() {
        generation = UUID(); isStarting = false
        if let engine { engine.stop(); engine.inputNode.removeTap(onBus: 0) }
        request?.endAudio(); task?.cancel()
        engine = nil; request = nil; task = nil; isRecording = false
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
}
