import Foundation
import UniformTypeIdentifiers

/// Service for file read/write operations
class FileService {
    static let shared = FileService()

    private init() {}

    // MARK: - Read Operations

    func readFile(at url: URL) throws -> String {
        let data = try Data(contentsOf: url)
        let encoding = FileEncoding.detect(from: data)

        guard let content = String(data: data, encoding: encoding.encoding) else {
            throw FileServiceError.decodingFailed
        }

        return content
    }

    func readFileWithEncoding(at url: URL) throws -> (content: String, encoding: FileEncoding) {
        let data = try Data(contentsOf: url)
        let encoding = FileEncoding.detect(from: data)

        guard let content = String(data: data, encoding: encoding.encoding) else {
            throw FileServiceError.decodingFailed
        }

        return (content, encoding)
    }

    // MARK: - Write Operations

    func writeFile(content: String, to url: URL, encoding: FileEncoding = .utf8) throws {
        guard let data = content.data(using: encoding.encoding) else {
            throw FileServiceError.encodingFailed
        }

        try data.write(to: url, options: .atomic)
    }

    // MARK: - File Info

    func getFileInfo(at url: URL) throws -> FileInfo {
        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)

        return FileInfo(
            name: url.lastPathComponent,
            path: url.path,
            size: attributes[.size] as? Int64 ?? 0,
            creationDate: attributes[.creationDate] as? Date,
            modificationDate: attributes[.modificationDate] as? Date,
            isReadOnly: !FileManager.default.isWritableFile(atPath: url.path)
        )
    }

    func fileExists(at url: URL) -> Bool {
        FileManager.default.fileExists(atPath: url.path)
    }

    // MARK: - Recent Files

    func validateRecentFiles(_ urls: [URL]) -> [URL] {
        urls.filter { fileExists(at: $0) }
    }
}

// MARK: - File Info

struct FileInfo {
    let name: String
    let path: String
    let size: Int64
    let creationDate: Date?
    let modificationDate: Date?
    let isReadOnly: Bool

    var formattedSize: String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: size)
    }
}

// MARK: - Errors

enum FileServiceError: LocalizedError {
    case decodingFailed
    case encodingFailed
    case fileNotFound
    case permissionDenied
    case unknown(Error)

    var errorDescription: String? {
        switch self {
        case .decodingFailed:
            return String(localized: "error.decoding.failed")
        case .encodingFailed:
            return String(localized: "error.encoding.failed")
        case .fileNotFound:
            return String(localized: "error.file.not.found")
        case .permissionDenied:
            return String(localized: "error.permission.denied")
        case .unknown(let error):
            return error.localizedDescription
        }
    }
}
