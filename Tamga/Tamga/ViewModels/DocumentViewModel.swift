import Foundation
import SwiftUI

/// ViewModel for document operations
@MainActor
class DocumentViewModel: ObservableObject {
    @Published var searchText: String = ""
    @Published var replaceText: String = ""
    @Published var isSearchVisible: Bool = false
    @Published var searchResults: [Range<String.Index>] = []
    @Published var currentSearchIndex: Int = 0

    private let fileService = FileService.shared

    // MARK: - Search Operations

    func search(in content: String) {
        guard !searchText.isEmpty else {
            searchResults = []
            return
        }

        var results: [Range<String.Index>] = []
        var searchStartIndex = content.startIndex

        while searchStartIndex < content.endIndex,
              let range = content.range(
                  of: searchText,
                  options: .caseInsensitive,
                  range: searchStartIndex..<content.endIndex
              ) {
            results.append(range)
            searchStartIndex = range.upperBound
        }

        searchResults = results
        if !results.isEmpty {
            currentSearchIndex = 0
        }
    }

    func findNext() {
        guard !searchResults.isEmpty else { return }
        currentSearchIndex = (currentSearchIndex + 1) % searchResults.count
    }

    func findPrevious() {
        guard !searchResults.isEmpty else { return }
        currentSearchIndex = (currentSearchIndex - 1 + searchResults.count) % searchResults.count
    }

    func replace(in content: inout String) -> Bool {
        guard currentSearchIndex < searchResults.count else { return false }
        let range = searchResults[currentSearchIndex]
        content.replaceSubrange(range, with: replaceText)
        search(in: content)
        return true
    }

    func replaceAll(in content: inout String) -> Int {
        guard !searchText.isEmpty else { return 0 }
        var count = 0
        while content.contains(searchText) {
            if let range = content.range(of: searchText, options: .caseInsensitive) {
                content.replaceSubrange(range, with: replaceText)
                count += 1
            }
        }
        searchResults = []
        return count
    }

    func toggleSearch() {
        isSearchVisible.toggle()
        if !isSearchVisible {
            searchText = ""
            replaceText = ""
            searchResults = []
        }
    }

    // MARK: - File Operations

    func openFile() async -> (URL, String)? {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = [.text, .sourceCode, .json, .xml, .html, .plainText]

        let response = await panel.beginSheetModal(for: NSApp.keyWindow ?? NSWindow())

        guard response == .OK, let url = panel.url else { return nil }

        do {
            let content = try fileService.readFile(at: url)
            return (url, content)
        } catch {
            print("Error opening file: \(error)")
            return nil
        }
    }

    func saveFile(content: String, existingPath: URL?) async -> URL? {
        if let path = existingPath {
            do {
                try fileService.writeFile(content: content, to: path)
                return path
            } catch {
                print("Error saving file: \(error)")
                return nil
            }
        } else {
            return await saveFileAs(content: content)
        }
    }

    func saveFileAs(content: String) async -> URL? {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.text, .sourceCode, .json, .xml, .html, .plainText]
        panel.canCreateDirectories = true
        panel.nameFieldStringValue = "untitled.txt"

        let response = await panel.beginSheetModal(for: NSApp.keyWindow ?? NSWindow())

        guard response == .OK, let url = panel.url else { return nil }

        do {
            try fileService.writeFile(content: content, to: url)
            return url
        } catch {
            print("Error saving file: \(error)")
            return nil
        }
    }
}
