import SwiftUI

@main
struct TamgaApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @FocusedValue(\.tabManager) var tabManager
    @FocusedValue(\.documentViewModel) var documentViewModel
    @ObservedObject private var appState = AppState.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(appState.currentTheme.colorScheme)
        }
        .windowStyle(.automatic)
        .windowToolbarStyle(.unified)
        .commands {
            // MARK: - File Menu
            CommandGroup(replacing: .newItem) {
                Button(String(localized: "new.tab")) {
                    tabManager?.createNewTab()
                }
                .keyboardShortcut("n", modifiers: .command)

                Button(String(localized: "open")) {
                    Task {
                        if let (url, content) = await documentViewModel?.openFile() {
                            tabManager?.openTab(with: url, content: content)
                        }
                    }
                }
                .keyboardShortcut("o", modifiers: .command)

                Divider()

                Button(String(localized: "save")) {
                    Task {
                        await saveCurrentTab()
                    }
                }
                .keyboardShortcut("s", modifiers: .command)
                .disabled(tabManager?.activeTab == nil)

                Button(String(localized: "save.as")) {
                    Task {
                        await saveCurrentTabAs()
                    }
                }
                .keyboardShortcut("s", modifiers: [.command, .shift])
                .disabled(tabManager?.activeTab == nil)

                Divider()

                Button(String(localized: "close.tab")) {
                    tabManager?.closeActiveTab()
                }
                .keyboardShortcut("w", modifiers: .command)
                .disabled(tabManager?.activeTab == nil)

                Button(String(localized: "close.all.tabs")) {
                    tabManager?.closeAllTabs()
                }
                .keyboardShortcut("w", modifiers: [.command, .shift, .option])

                Divider()

                // Recent files submenu
                Menu(String(localized: "recent.files")) {
                    if appState.recentFiles.isEmpty {
                        Text(String(localized: "no.recent.files"))
                            .foregroundColor(.secondary)
                    } else {
                        ForEach(appState.recentFiles, id: \.self) { url in
                            Button(url.lastPathComponent) {
                                openRecentFile(url)
                            }
                        }

                        Divider()

                        Button(String(localized: "clear.recent")) {
                            appState.clearRecentFiles()
                        }
                    }
                }
            }

            // MARK: - Edit Menu
            CommandGroup(after: .undoRedo) {
                Divider()

                Button(String(localized: "find")) {
                    documentViewModel?.toggleSearch()
                }
                .keyboardShortcut("f", modifiers: .command)

                Button(String(localized: "find.next")) {
                    documentViewModel?.findNext()
                }
                .keyboardShortcut("g", modifiers: .command)

                Button(String(localized: "find.previous")) {
                    documentViewModel?.findPrevious()
                }
                .keyboardShortcut("g", modifiers: [.command, .shift])

                Divider()

                Button(String(localized: "go.to.line")) {
                    documentViewModel?.toggleGoToLine()
                }
                .keyboardShortcut("l", modifiers: .command)

                Divider()

                Button(String(localized: "duplicate.line")) {
                    NotificationCenter.default.post(name: .duplicateLine, object: nil)
                }
                .keyboardShortcut("d", modifiers: .command)

                Button(String(localized: "move.line.up")) {
                    NotificationCenter.default.post(name: .moveLineUp, object: nil)
                }
                .keyboardShortcut(.upArrow, modifiers: .option)

                Button(String(localized: "move.line.down")) {
                    NotificationCenter.default.post(name: .moveLineDown, object: nil)
                }
                .keyboardShortcut(.downArrow, modifiers: .option)

                Divider()

                // Sort Lines submenu
                Menu(String(localized: "sort.lines")) {
                    Button(String(localized: "sort.lines.ascending")) {
                        NotificationCenter.default.post(name: .sortLinesAscending, object: nil)
                    }
                    Button(String(localized: "sort.lines.descending")) {
                        NotificationCenter.default.post(name: .sortLinesDescending, object: nil)
                    }
                }

                Button(String(localized: "remove.duplicate.lines")) {
                    NotificationCenter.default.post(name: .removeDuplicateLines, object: nil)
                }

                // Change Case submenu
                Menu(String(localized: "change.case")) {
                    Button(String(localized: "uppercase")) {
                        NotificationCenter.default.post(name: .uppercaseSelection, object: nil)
                    }
                    .keyboardShortcut("u", modifiers: [.command, .shift])

                    Button(String(localized: "lowercase")) {
                        NotificationCenter.default.post(name: .lowercaseSelection, object: nil)
                    }
                    .keyboardShortcut("l", modifiers: [.command, .shift])

                    Button(String(localized: "capitalize")) {
                        NotificationCenter.default.post(name: .capitalizeSelection, object: nil)
                    }
                }

                Divider()

                // JSON submenu
                Menu(String(localized: "json")) {
                    Button(String(localized: "format.json")) {
                        NotificationCenter.default.post(name: .formatJSON, object: nil)
                    }
                    .keyboardShortcut("j", modifiers: [.command, .shift])

                    Button(String(localized: "minify.json")) {
                        NotificationCenter.default.post(name: .minifyJSON, object: nil)
                    }
                }
            }

            // MARK: - View Menu
            CommandGroup(after: .toolbar) {
                Divider()

                Toggle(String(localized: "word.wrap"), isOn: $appState.isWordWrapEnabled)
                    .keyboardShortcut("w", modifiers: [.command, .option])

                Toggle(String(localized: "line.numbers"), isOn: $appState.showLineNumbers)

                Toggle(String(localized: "status.bar"), isOn: $appState.isStatusBarVisible)

                Divider()

                Button(String(localized: "zoom.in")) {
                    appState.fontSize = min(appState.fontSize + 2, 48)
                }
                .keyboardShortcut("+", modifiers: .command)

                Button(String(localized: "zoom.out")) {
                    appState.fontSize = max(appState.fontSize - 2, 8)
                }
                .keyboardShortcut("-", modifiers: .command)

                Button(String(localized: "reset.zoom")) {
                    appState.fontSize = 14
                }
                .keyboardShortcut("0", modifiers: .command)

                Divider()

                // Theme submenu
                Menu(String(localized: "theme")) {
                    ForEach(AppTheme.allCases, id: \.self) { theme in
                        Button {
                            appState.currentTheme = theme
                        } label: {
                            HStack {
                                Text(theme.displayName)
                                if appState.currentTheme == theme {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                }
            }

            // MARK: - Tab Navigation
            CommandGroup(after: .windowArrangement) {
                Divider()

                Button(String(localized: "next.tab")) {
                    tabManager?.selectNextTab()
                }
                .keyboardShortcut("]", modifiers: [.command, .shift])

                Button(String(localized: "previous.tab")) {
                    tabManager?.selectPreviousTab()
                }
                .keyboardShortcut("[", modifiers: [.command, .shift])

                Divider()

                // Tab shortcuts 1-9
                ForEach(1...9, id: \.self) { index in
                    Button("Tab \(index)") {
                        tabManager?.selectTab(at: index - 1)
                    }
                    .keyboardShortcut(KeyEquivalent(Character("\(index)")), modifiers: .command)
                }
            }

            // MARK: - Help Menu
            CommandGroup(replacing: .help) {
                Button(String(localized: "about.tamga")) {
                    showAboutPanel()
                }
            }
        }
    }

    // MARK: - Helper Methods

    private func saveCurrentTab() async {
        guard let tabManager = tabManager,
              let tab = tabManager.activeTab else { return }

        if let url = await documentViewModel?.saveFile(
            content: tab.content,
            existingPath: tab.filePath
        ) {
            tabManager.markAsSaved(id: tab.id, filePath: url)
        }
    }

    private func saveCurrentTabAs() async {
        guard let tabManager = tabManager,
              let tab = tabManager.activeTab else { return }

        if let url = await documentViewModel?.saveFileAs(content: tab.content) {
            tabManager.markAsSaved(id: tab.id, filePath: url)
        }
    }

    private func openRecentFile(_ url: URL) {
        do {
            let content = try FileService.shared.readFile(at: url)
            tabManager?.openTab(with: url, content: content)
        } catch {
            print("Failed to open recent file: \(error)")
        }
    }

    private func showAboutPanel() {
        let alert = NSAlert()
        alert.messageText = "Tamga"
        alert.informativeText = String(localized: "about.description")
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
}

// MARK: - App Delegate

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationWillTerminate(_ notification: Notification) {
        AppState.shared.saveSettings()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        true
    }
}
