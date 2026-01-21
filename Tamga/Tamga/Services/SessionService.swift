import Foundation

/// Service for saving and restoring application sessions
class SessionService {
    static let shared = SessionService()

    private let fileManager = FileManager.default
    private let sessionFileName = "session.json"

    private var applicationSupportDirectory: URL {
        let paths = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)
        let appSupportDir = paths[0].appendingPathComponent("Tamga")

        if !fileManager.fileExists(atPath: appSupportDir.path) {
            try? fileManager.createDirectory(at: appSupportDir, withIntermediateDirectories: true)
        }

        return appSupportDir
    }

    private var sessionFileURL: URL {
        applicationSupportDirectory.appendingPathComponent(sessionFileName)
    }

    private init() {}

    // MARK: - Session Data

    struct SessionData: Codable {
        let tabs: [TabData]
        let activeTabId: UUID?
        let savedAt: Date

        struct TabData: Codable {
            let id: UUID
            let title: String
            let content: String
            let filePath: String?
            let cursorPosition: Int
            let scrollPosition: CGFloat
            let languageRaw: String
            let encoding: String
            let createdAt: Date
            let lastModifiedAt: Date
        }
    }

    // MARK: - Save Session

    func saveSession(tabs: [Tab], activeTabId: UUID?) {
        let tabData = tabs.map { tab in
            SessionData.TabData(
                id: tab.id,
                title: tab.title,
                content: tab.content,
                filePath: tab.filePath?.path,
                cursorPosition: tab.cursorPosition,
                scrollPosition: tab.scrollPosition,
                languageRaw: tab.language.rawValue,
                encoding: tab.encoding,
                createdAt: tab.createdAt,
                lastModifiedAt: tab.lastModifiedAt
            )
        }

        let sessionData = SessionData(
            tabs: tabData,
            activeTabId: activeTabId,
            savedAt: Date()
        )

        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            let data = try encoder.encode(sessionData)
            try data.write(to: sessionFileURL, options: .atomic)
        } catch {
            print("Failed to save session: \(error)")
        }
    }

    // MARK: - Restore Session

    func restoreSession() -> (tabs: [Tab], activeTabId: UUID?)? {
        guard fileManager.fileExists(atPath: sessionFileURL.path) else {
            return nil
        }

        do {
            let data = try Data(contentsOf: sessionFileURL)
            let sessionData = try JSONDecoder().decode(SessionData.self, from: data)

            let tabs = sessionData.tabs.map { tabData -> Tab in
                Tab(
                    id: tabData.id,
                    title: tabData.title,
                    content: tabData.content,
                    filePath: tabData.filePath.map { URL(fileURLWithPath: $0) },
                    isDirty: tabData.filePath == nil && !tabData.content.isEmpty,
                    cursorPosition: tabData.cursorPosition,
                    scrollPosition: tabData.scrollPosition,
                    language: SyntaxLanguage(rawValue: tabData.languageRaw) ?? .plainText,
                    encoding: tabData.encoding,
                    createdAt: tabData.createdAt,
                    lastModifiedAt: tabData.lastModifiedAt
                )
            }

            return (tabs, sessionData.activeTabId)
        } catch {
            print("Failed to restore session: \(error)")
            return nil
        }
    }

    // MARK: - Clear Session

    func clearSession() {
        try? fileManager.removeItem(at: sessionFileURL)
    }

    // MARK: - Temp Files

    private var tempDirectory: URL {
        applicationSupportDirectory.appendingPathComponent("temp")
    }

    func saveTempFile(content: String, id: UUID) -> URL? {
        if !fileManager.fileExists(atPath: tempDirectory.path) {
            try? fileManager.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
        }

        let tempFileURL = tempDirectory.appendingPathComponent("\(id.uuidString).tmp")

        do {
            try content.write(to: tempFileURL, atomically: true, encoding: .utf8)
            return tempFileURL
        } catch {
            print("Failed to save temp file: \(error)")
            return nil
        }
    }

    func loadTempFile(id: UUID) -> String? {
        let tempFileURL = tempDirectory.appendingPathComponent("\(id.uuidString).tmp")

        guard fileManager.fileExists(atPath: tempFileURL.path) else {
            return nil
        }

        return try? String(contentsOf: tempFileURL, encoding: .utf8)
    }

    func deleteTempFile(id: UUID) {
        let tempFileURL = tempDirectory.appendingPathComponent("\(id.uuidString).tmp")
        try? fileManager.removeItem(at: tempFileURL)
    }

    func clearTempFiles() {
        try? fileManager.removeItem(at: tempDirectory)
    }
}
