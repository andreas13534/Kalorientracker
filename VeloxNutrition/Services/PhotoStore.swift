import Foundation
import UIKit
import ImageIO

struct PhotoStore {
    let directory: URL
    init(directory: URL = LocalStorage.directory.appendingPathComponent("Photos", isDirectory: true)) {
        self.directory = directory
    }
    // Decode into a thumbnail before loading pixels, so large HEIC/JPEG files don't exhaust RAM.
    static func compress(_ data: Data) throws -> Data {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceThumbnailMaxPixelSize: 1600,
                kCGImageSourceShouldCacheImmediately: true
              ] as CFDictionary),
              let jpeg = UIImage(cgImage: cgImage).jpegData(compressionQuality: 0.78), jpeg.count <= 4_000_000 else { throw StoreError.photo }
        return jpeg
    }
    func save(_ jpeg: Data) throws -> String {
        try LocalStorage.prepare(directory)
        let filename = UUID().uuidString + ".jpg"
        try jpeg.write(to: directory.appendingPathComponent(filename), options: [.atomic, .completeFileProtection])
        return filename
    }
    func url(_ filename: String) -> URL? {
        guard filename == URL(fileURLWithPath: filename).lastPathComponent, filename.hasSuffix(".jpg"), !filename.contains("..") else { return nil }
        return directory.appendingPathComponent(filename)
    }
    func read(_ filename: String?) -> Data? {
        guard let filename, let url = url(filename) else { return nil }
        return try? Data(contentsOf: url)
    }
    func remove(_ filename: String?) throws {
        guard let filename, let url = url(filename), FileManager.default.fileExists(atPath: url.path) else { return }
        try FileManager.default.removeItem(at: url)
    }
    func cleanOrphans(keeping filenames: Set<String>) throws {
        guard FileManager.default.fileExists(atPath: directory.path) else { return }
        for file in try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil) where file.pathExtension == "jpg" && !filenames.contains(file.lastPathComponent) {
            try FileManager.default.removeItem(at: file)
        }
    }
}

enum LocalStorage {
    static var directory: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("VeloxNutrition", isDirectory: true)
    }
    static func prepare(_ directory: URL) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true,
            attributes: [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication])
        var url = directory
        var values = URLResourceValues(); values.isExcludedFromBackup = true
        try url.setResourceValues(values)
    }
}
