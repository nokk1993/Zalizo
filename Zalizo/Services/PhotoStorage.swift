import Foundation
import UIKit

/// Photos live as JPEG files in Documents/<folder>; the database stores only the file name.
/// They are not added to the system photo library.
enum PhotoStorage {
    enum Folder: String, CaseIterable {
        case exercisePhotos = "ExercisePhotos"
        case progressPhotos = "ProgressPhotos"
    }

    enum StorageError: LocalizedError {
        case unreadableImage

        var errorDescription: String? { String(localized: "Не вдалося прочитати зображення") }
    }

    static let maxPixelSize: CGFloat = 1600

    static func directory(_ folder: Folder) throws -> URL {
        let url = URL.documentsDirectory.appending(path: folder.rawValue, directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    static func url(for fileName: String, in folder: Folder) -> URL {
        URL.documentsDirectory.appending(path: folder.rawValue).appending(path: fileName)
    }

    /// Downscales and stores image data (e.g. from PhotosPicker). Returns the new file name.
    static func save(_ data: Data, in folder: Folder) throws -> String {
        guard let image = UIImage(data: data) else { throw StorageError.unreadableImage }
        let scaled = downscale(image)
        guard let jpeg = scaled.jpegData(compressionQuality: 0.8) else { throw StorageError.unreadableImage }
        let name = "\(UUID().uuidString).jpg"
        try jpeg.write(to: try directory(folder).appending(path: name), options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
        return name
    }

    static func loadImage(_ fileName: String, in folder: Folder) -> UIImage? {
        UIImage(contentsOfFile: url(for: fileName, in: folder).path)
    }

    static func delete(_ fileName: String, in folder: Folder) {
        try? FileManager.default.removeItem(at: url(for: fileName, in: folder))
    }

    private static func downscale(_ image: UIImage) -> UIImage {
        let longest = max(image.size.width, image.size.height) * image.scale
        guard longest > maxPixelSize else { return image }
        let factor = maxPixelSize / longest
        let size = CGSize(width: image.size.width * image.scale * factor, height: image.size.height * image.scale * factor)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        return UIGraphicsImageRenderer(size: size, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
    }
}
