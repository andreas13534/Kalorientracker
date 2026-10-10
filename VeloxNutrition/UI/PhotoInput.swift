import SwiftUI
import PhotosUI
import AVFoundation

struct PhotoInput: View {
    @Binding var jpeg: Data?
    var filename: String?
    var changed: () -> Void = {}
    var onProcessingChange: (Bool) -> Void = { _ in }
    @State private var selection: PhotosPickerItem?
    @State private var showCamera = false
    @State private var openingCamera = false
    @State private var processing = false
    @State private var loadingID = UUID()
    @State private var errorMessage: String?
    var body: some View {
        VStack(spacing: 14) {
            if jpeg != nil || filename != nil {
                MealPhoto(filename: filename, jpeg: jpeg, size: 180).frame(maxWidth: .infinity)
                Button("Foto entfernen", role: .destructive) { jpeg = nil; selection = nil; changed() }
                    .font(Theme.font(13)).foregroundStyle(Theme.secondary)
            } else {
                VStack(spacing: 10) {
                    Image(systemName: "camera.viewfinder").font(.system(size: 42, weight: .light)).foregroundStyle(Theme.mint)
                    Text("Was steht auf deinem Teller?").font(Theme.font(17, weight: .medium))
                    Text("Ein gut beleuchtetes Foto hilft beim Schätzen.").font(Theme.font(12)).foregroundStyle(Theme.secondary).multilineTextAlignment(.center)
                }.frame(maxWidth: .infinity).padding(.vertical, 25)
            }
            HStack(spacing: 10) {
                Button { Task { await openCamera() } } label: { Label("Kamera", systemImage: "camera") }
                PhotosPicker(selection: $selection, matching: .images, photoLibrary: .shared()) { Label("Mediathek", systemImage: "photo") }
            }.buttonStyle(SecondaryButtonStyle()).disabled(processing || openingCamera)
            if processing { ProgressView("Foto vorbereiten …").tint(.white) }
            if let errorMessage { InlineError(message: errorMessage) }
        }
        .onChange(of: processing) { _, value in onProcessingChange(value) }
        .onDisappear { onProcessingChange(false) }
        .task(id: selection) {
            guard let selection else { return }
            let token = UUID(); loadingID = token
            processing = true; errorMessage = nil
            defer { if loadingID == token { processing = false } }
            do {
                guard let data = try await selection.loadTransferable(type: Data.self) else { throw StoreError.photo }
                let compressed = try await Task.detached(priority: .userInitiated) { try PhotoStore.compress(data) }.value
                try Task.checkCancellation()
                guard loadingID == token else { return }
                jpeg = compressed; changed()
            } catch is CancellationError { }
            catch { if loadingID == token { errorMessage = "Das Foto konnte nicht geladen werden. Bei iCloud-Fotos kann eine Internetverbindung nötig sein." } }
        }
        .fullScreenCover(isPresented: $showCamera) {
            CameraPicker { data in
                do { jpeg = try PhotoStore.compress(data); changed() }
                catch { errorMessage = error.localizedDescription }
            } onFailure: { message in errorMessage = message }
                .ignoresSafeArea()
        }
    }
    @MainActor private func openCamera() async {
        guard !openingCamera else { return }
        openingCamera = true
        defer { openingCamera = false }
        guard UIImagePickerController.isSourceTypeAvailable(.camera) else {
            errorMessage = "Auf diesem Gerät ist keine Kamera verfügbar. Wähle ein Foto aus der Mediathek."; return
        }
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        var authorized = status == .authorized
        if status == .notDetermined { authorized = await AVCaptureDevice.requestAccess(for: .video) }
        guard authorized else {
            errorMessage = "Erlaube den Kamerazugriff in den iPhone-Einstellungen für Velox Nutrition."; return
        }
        showCamera = true
    }
}

struct CameraPicker: UIViewControllerRepresentable {
    let onPhoto: (Data) -> Void
    let onFailure: (String) -> Void
    @Environment(\.dismiss) private var dismiss
    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController(); picker.sourceType = .camera; picker.delegate = context.coordinator
        return picker
    }
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: CameraPicker
        init(parent: CameraPicker) { self.parent = parent }
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let image = info[.originalImage] as? UIImage, let data = image.jpegData(compressionQuality: 0.85) { parent.onPhoto(data) }
            else { parent.onFailure("Die Kamera konnte kein lesbares Foto liefern. Bitte nimm das Foto erneut auf.") }
            parent.dismiss()
        }
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) { parent.dismiss() }
    }
}
