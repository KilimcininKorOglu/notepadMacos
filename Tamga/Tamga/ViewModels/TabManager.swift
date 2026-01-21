import Foundation
import SwiftUI

/// Manages all tabs in the application
@MainActor
class TabManager: ObservableObject {
    @Published var tabs: [Tab] = []
    @Published var activeTabId: UUID?
    @Published var draggedTab: Tab?

    private var untitledCounter: Int = 1

    var activeTab: Tab? {
        guard let id = activeTabId else { return nil }
        return tabs.first { $0.id == id }
    }

    var activeTabIndex: Int? {
        guard let id = activeTabId else { return nil }
        return tabs.firstIndex { $0.id == id }
    }

    var hasUnsavedChanges: Bool {
        tabs.contains { $0.isDirty }
    }

    init() {
        // Start with one empty tab
        createNewTab()
    }

    // MARK: - Tab Operations

    func createNewTab() {
        let newTab = Tab.newUntitled(number: untitledCounter)
        untitledCounter += 1
        tabs.append(newTab)
        activeTabId = newTab.id
    }

    func openTab(with url: URL, content: String) {
        // Check if file is already open
        if let existingTab = tabs.first(where: { $0.filePath == url }) {
            activeTabId = existingTab.id
            return
        }

        var newTab = Tab(
            title: url.lastPathComponent,
            content: content,
            filePath: url,
            isDirty: false
        )
        newTab.detectLanguage()

        tabs.append(newTab)
        activeTabId = newTab.id

        AppState.shared.addRecentFile(url)
    }

    func closeTab(id: UUID) {
        guard let index = tabs.firstIndex(where: { $0.id == id }) else { return }

        tabs.remove(at: index)

        if tabs.isEmpty {
            createNewTab()
        } else if activeTabId == id {
            // Select adjacent tab
            let newIndex = min(index, tabs.count - 1)
            activeTabId = tabs[newIndex].id
        }
    }

    func closeActiveTab() {
        guard let id = activeTabId else { return }
        closeTab(id: id)
    }

    func closeAllTabs() {
        tabs.removeAll()
        untitledCounter = 1
        createNewTab()
    }

    func closeOtherTabs(except id: UUID) {
        tabs.removeAll { $0.id != id }
        activeTabId = id
    }

    func selectTab(id: UUID) {
        if tabs.contains(where: { $0.id == id }) {
            activeTabId = id
        }
    }

    func selectTab(at index: Int) {
        guard index >= 0, index < tabs.count else { return }
        activeTabId = tabs[index].id
    }

    func selectNextTab() {
        guard let currentIndex = activeTabIndex else { return }
        let nextIndex = (currentIndex + 1) % tabs.count
        activeTabId = tabs[nextIndex].id
    }

    func selectPreviousTab() {
        guard let currentIndex = activeTabIndex else { return }
        let prevIndex = (currentIndex - 1 + tabs.count) % tabs.count
        activeTabId = tabs[prevIndex].id
    }

    // MARK: - Tab Content Updates

    func updateContent(_ content: String, for id: UUID) {
        guard let index = tabs.firstIndex(where: { $0.id == id }) else { return }
        tabs[index].content = content
        tabs[index].isDirty = true
        tabs[index].lastModifiedAt = Date()
    }

    func updateCursorPosition(_ position: Int, for id: UUID) {
        guard let index = tabs.firstIndex(where: { $0.id == id }) else { return }
        tabs[index].cursorPosition = position
    }

    func updateScrollPosition(_ position: CGFloat, for id: UUID) {
        guard let index = tabs.firstIndex(where: { $0.id == id }) else { return }
        tabs[index].scrollPosition = position
    }

    func markAsSaved(id: UUID, filePath: URL) {
        guard let index = tabs.firstIndex(where: { $0.id == id }) else { return }
        tabs[index].isDirty = false
        tabs[index].filePath = filePath
        tabs[index].updateTitleFromPath()
        tabs[index].detectLanguage()

        AppState.shared.addRecentFile(filePath)
    }

    func setLanguage(_ language: SyntaxLanguage, for id: UUID) {
        guard let index = tabs.firstIndex(where: { $0.id == id }) else { return }
        tabs[index].language = language
    }

    func setEncoding(_ encoding: String, for id: UUID) {
        guard let index = tabs.firstIndex(where: { $0.id == id }) else { return }
        tabs[index].encoding = encoding
    }

    // MARK: - Tab Reordering

    func moveTab(from sourceIndex: Int, to destinationIndex: Int) {
        guard sourceIndex != destinationIndex,
              sourceIndex >= 0, sourceIndex < tabs.count,
              destinationIndex >= 0, destinationIndex < tabs.count else { return }

        let tab = tabs.remove(at: sourceIndex)
        tabs.insert(tab, at: destinationIndex)
    }

    func moveTab(id: UUID, to destinationIndex: Int) {
        guard let sourceIndex = tabs.firstIndex(where: { $0.id == id }) else { return }
        moveTab(from: sourceIndex, to: destinationIndex)
    }

    // MARK: - Utility

    func getTab(by id: UUID) -> Tab? {
        tabs.first { $0.id == id }
    }

    func getDirtyTabs() -> [Tab] {
        tabs.filter { $0.isDirty }
    }

    func getDocumentInfo(for id: UUID) -> DocumentInfo? {
        guard let tab = getTab(by: id) else { return nil }
        return DocumentInfo(content: tab.content, cursorPosition: tab.cursorPosition)
    }
}
