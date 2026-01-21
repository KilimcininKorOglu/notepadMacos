import Foundation
import SwiftUI

/// Global application state
@MainActor
class AppState: ObservableObject {
    static let shared = AppState()

    @Published var isWordWrapEnabled: Bool = true
    @Published var isStatusBarVisible: Bool = true
    @Published var currentTheme: AppTheme = .system
    @Published var fontSize: CGFloat = 14
    @Published var fontName: String = "SF Mono"
    @Published var showLineNumbers: Bool = true
    @Published var recentFiles: [URL] = []

    private let userDefaults = UserDefaults.standard
    private let recentFilesKey = "recentFiles"
    private let maxRecentFiles = 10

    private init() {
        loadSettings()
    }

    func loadSettings() {
        isWordWrapEnabled = userDefaults.object(forKey: "wordWrap") as? Bool ?? true
        isStatusBarVisible = userDefaults.object(forKey: "statusBar") as? Bool ?? true
        fontSize = userDefaults.object(forKey: "fontSize") as? CGFloat ?? 14
        fontName = userDefaults.string(forKey: "fontName") ?? "SF Mono"
        showLineNumbers = userDefaults.object(forKey: "lineNumbers") as? Bool ?? true

        if let themeRaw = userDefaults.string(forKey: "theme"),
           let theme = AppTheme(rawValue: themeRaw) {
            currentTheme = theme
        }

        if let recentData = userDefaults.data(forKey: recentFilesKey),
           let urls = try? JSONDecoder().decode([URL].self, from: recentData) {
            recentFiles = urls.filter { FileManager.default.fileExists(atPath: $0.path) }
        }
    }

    func saveSettings() {
        userDefaults.set(isWordWrapEnabled, forKey: "wordWrap")
        userDefaults.set(isStatusBarVisible, forKey: "statusBar")
        userDefaults.set(fontSize, forKey: "fontSize")
        userDefaults.set(fontName, forKey: "fontName")
        userDefaults.set(showLineNumbers, forKey: "lineNumbers")
        userDefaults.set(currentTheme.rawValue, forKey: "theme")

        if let data = try? JSONEncoder().encode(recentFiles) {
            userDefaults.set(data, forKey: recentFilesKey)
        }
    }

    func addRecentFile(_ url: URL) {
        recentFiles.removeAll { $0 == url }
        recentFiles.insert(url, at: 0)
        if recentFiles.count > maxRecentFiles {
            recentFiles = Array(recentFiles.prefix(maxRecentFiles))
        }
        saveSettings()
    }

    func clearRecentFiles() {
        recentFiles.removeAll()
        saveSettings()
    }
}

/// Application theme options
enum AppTheme: String, CaseIterable {
    case system = "System"
    case light = "Light"
    case dark = "Dark"

    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }

    var displayName: String {
        switch self {
        case .system: return String(localized: "system")
        case .light: return String(localized: "light")
        case .dark: return String(localized: "dark")
        }
    }
}
