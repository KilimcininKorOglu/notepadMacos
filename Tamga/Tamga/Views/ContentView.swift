import SwiftUI

/// Main content view containing tabs, editor, and status bar
struct ContentView: View {
    @StateObject private var tabManager = TabManager()
    @StateObject private var documentViewModel = DocumentViewModel()
    @ObservedObject private var appState = AppState.shared

    @State private var currentDocumentInfo = DocumentInfo()

    var body: some View {
        VStack(spacing: 0) {
            // Tab bar
            TabBarView(tabManager: tabManager)

            Divider()

            // Editor
            if let activeTab = tabManager.activeTab {
                EditorView(
                    text: Binding(
                        get: { activeTab.content },
                        set: { newContent in
                            tabManager.updateContent(newContent, for: activeTab.id)
                            updateDocumentInfo(content: newContent)
                        }
                    ),
                    language: activeTab.language,
                    showLineNumbers: appState.showLineNumbers,
                    isWordWrapEnabled: appState.isWordWrapEnabled,
                    fontSize: appState.fontSize,
                    fontName: appState.fontName
                )
                .id(activeTab.id)
            } else {
                emptyStateView
            }

            // Status bar
            if appState.isStatusBarVisible, let activeTab = tabManager.activeTab {
                Divider()

                StatusBarView(
                    documentInfo: currentDocumentInfo,
                    language: activeTab.language,
                    encoding: activeTab.encoding,
                    onLanguageChange: { language in
                        tabManager.setLanguage(language, for: activeTab.id)
                    }
                )
            }
        }
        .frame(minWidth: 600, minHeight: 400)
        .onAppear {
            restoreSession()
        }
        .onDisappear {
            saveSession()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.willTerminateNotification)) { _ in
            saveSession()
        }
        .onChange(of: tabManager.activeTabId) { _ in
            if let tab = tabManager.activeTab {
                updateDocumentInfo(content: tab.content)
            }
        }
        .focusedSceneValue(\.tabManager, tabManager)
        .focusedSceneValue(\.documentViewModel, documentViewModel)
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "doc.text")
                .font(.system(size: 48))
                .foregroundColor(.secondary)

            Text(String(localized: "no.open.files"))
                .font(.title2)
                .foregroundColor(.secondary)

            Button(String(localized: "new.document")) {
                tabManager.createNewTab()
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Session Management

    private func saveSession() {
        SessionService.shared.saveSession(
            tabs: tabManager.tabs,
            activeTabId: tabManager.activeTabId
        )
    }

    private func restoreSession() {
        if let session = SessionService.shared.restoreSession() {
            if !session.tabs.isEmpty {
                // Clear default tab and restore session
                tabManager.tabs = session.tabs
                tabManager.activeTabId = session.activeTabId ?? session.tabs.first?.id
            }
        }
    }

    // MARK: - Document Info

    private func updateDocumentInfo(content: String) {
        currentDocumentInfo = DocumentInfo(
            content: content,
            cursorPosition: 0 // TODO: Get actual cursor position
        )
    }
}

// MARK: - Focused Values

struct TabManagerKey: FocusedValueKey {
    typealias Value = TabManager
}

struct DocumentViewModelKey: FocusedValueKey {
    typealias Value = DocumentViewModel
}

extension FocusedValues {
    var tabManager: TabManager? {
        get { self[TabManagerKey.self] }
        set { self[TabManagerKey.self] = newValue }
    }

    var documentViewModel: DocumentViewModel? {
        get { self[DocumentViewModelKey.self] }
        set { self[DocumentViewModelKey.self] = newValue }
    }
}

#Preview {
    ContentView()
}
