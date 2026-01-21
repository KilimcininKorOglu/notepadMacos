import SwiftUI
import AppKit

/// Main text editor view with line numbers and syntax highlighting
struct EditorView: View {
    @Binding var text: String
    let language: SyntaxLanguage
    let showLineNumbers: Bool
    let isWordWrapEnabled: Bool
    let fontSize: CGFloat
    let fontName: String
    var goToPosition: Int? = nil

    @Environment(\.colorScheme) private var colorScheme
    @State private var lineCount: Int = 1
    @State private var scrollOffset: CGFloat = 0

    var body: some View {
        GeometryReader { geometry in
            HStack(spacing: 0) {
                if showLineNumbers {
                    LineNumbersView(
                        lineCount: lineCount,
                        fontSize: fontSize,
                        scrollOffset: scrollOffset
                    )
                    .frame(width: lineNumberWidth)

                    Divider()
                }

                HighlightedTextEditor(
                    text: $text,
                    language: language,
                    isDarkMode: colorScheme == .dark,
                    fontSize: fontSize,
                    fontName: fontName,
                    isWordWrapEnabled: isWordWrapEnabled,
                    goToPosition: goToPosition,
                    onLineCountChange: { count in
                        lineCount = count
                    },
                    onScrollChange: { offset in
                        scrollOffset = offset
                    }
                )
            }
        }
    }

    private var lineNumberWidth: CGFloat {
        let digits = String(lineCount).count
        return CGFloat(max(digits, 3)) * 10 + 20
    }
}

// MARK: - Line Numbers View

struct LineNumbersView: View {
    let lineCount: Int
    let fontSize: CGFloat
    let scrollOffset: CGFloat

    @Environment(\.colorScheme) private var colorScheme

    private var backgroundColor: Color {
        colorScheme == .dark
            ? Color(nsColor: NSColor(red: 0.15, green: 0.15, blue: 0.17, alpha: 1))
            : Color(nsColor: .controlBackgroundColor).opacity(0.5)
    }

    private var textColor: Color {
        colorScheme == .dark
            ? Color(nsColor: NSColor(red: 0.5, green: 0.5, blue: 0.55, alpha: 1))
            : Color.secondary
    }

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .trailing, spacing: 0) {
                ForEach(1...max(lineCount, 1), id: \.self) { lineNumber in
                    Text("\(lineNumber)")
                        .font(.system(size: fontSize, design: .monospaced))
                        .foregroundColor(textColor)
                        .frame(height: fontSize * 1.4)
                }
            }
            .padding(.horizontal, 8)
            .padding(.top, 8)
            .offset(y: -scrollOffset)
        }
        .disabled(true)
        .background(backgroundColor)
    }
}

// MARK: - Highlighted Text Editor (NSViewRepresentable)

struct HighlightedTextEditor: NSViewRepresentable {
    @Binding var text: String
    let language: SyntaxLanguage
    let isDarkMode: Bool
    let fontSize: CGFloat
    let fontName: String
    let isWordWrapEnabled: Bool
    let goToPosition: Int?
    let onLineCountChange: (Int) -> Void
    let onScrollChange: (CGFloat) -> Void

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        let textView = TamgaTextView()

        textView.delegate = context.coordinator
        textView.isEditable = true
        textView.isSelectable = true
        textView.allowsUndo = true
        textView.isRichText = false
        textView.usesFindBar = true
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false

        textView.textContainerInset = NSSize(width: 8, height: 8)

        let font = NSFont(name: fontName, size: fontSize) ?? NSFont.monospacedSystemFont(ofSize: fontSize, weight: .regular)
        textView.font = font
        textView.typingAttributes = [.font: font]

        // Set background and text colors based on theme
        updateColors(textView: textView, isDarkMode: isDarkMode)

        scrollView.documentView = textView
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = !isWordWrapEnabled
        scrollView.autohidesScrollers = true

        if isWordWrapEnabled {
            textView.textContainer?.widthTracksTextView = true
            textView.textContainer?.containerSize = NSSize(width: 0, height: CGFloat.greatestFiniteMagnitude)
        } else {
            textView.textContainer?.widthTracksTextView = false
            textView.textContainer?.containerSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        }

        context.coordinator.textView = textView
        context.coordinator.scrollView = scrollView

        // Observe scroll changes
        NotificationCenter.default.addObserver(
            context.coordinator,
            selector: #selector(Coordinator.scrollViewDidScroll(_:)),
            name: NSView.boundsDidChangeNotification,
            object: scrollView.contentView
        )
        scrollView.contentView.postsBoundsChangedNotifications = true

        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? NSTextView else { return }

        // Update text if changed externally
        if textView.string != text {
            let selectedRanges = textView.selectedRanges
            textView.string = text
            textView.selectedRanges = selectedRanges
        }

        // Update font
        let font = NSFont(name: fontName, size: fontSize) ?? NSFont.monospacedSystemFont(ofSize: fontSize, weight: .regular)
        textView.font = font

        // Update word wrap
        if isWordWrapEnabled {
            textView.textContainer?.widthTracksTextView = true
            textView.textContainer?.containerSize = NSSize(
                width: scrollView.contentView.bounds.width - 16,
                height: CGFloat.greatestFiniteMagnitude
            )
            scrollView.hasHorizontalScroller = false
        } else {
            textView.textContainer?.widthTracksTextView = false
            textView.textContainer?.containerSize = NSSize(
                width: CGFloat.greatestFiniteMagnitude,
                height: CGFloat.greatestFiniteMagnitude
            )
            scrollView.hasHorizontalScroller = true
        }

        // Update colors for dark mode
        updateColors(textView: textView, isDarkMode: isDarkMode)

        // Apply syntax highlighting
        context.coordinator.applySyntaxHighlighting(language: language, isDarkMode: isDarkMode)

        // Handle go to position
        if let position = goToPosition, position != context.coordinator.lastGoToPosition {
            context.coordinator.lastGoToPosition = position
            context.coordinator.scrollToPosition(position)
        }
    }

    private func updateColors(textView: NSTextView, isDarkMode: Bool) {
        if isDarkMode {
            textView.backgroundColor = NSColor(red: 0.12, green: 0.12, blue: 0.14, alpha: 1)
            textView.insertionPointColor = NSColor.white
        } else {
            textView.backgroundColor = NSColor.textBackgroundColor
            textView.insertionPointColor = NSColor.textColor
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, NSTextViewDelegate {
        var parent: HighlightedTextEditor
        weak var textView: NSTextView?
        weak var scrollView: NSScrollView?
        var lastGoToPosition: Int?

        private let highlighter = SyntaxHighlighter.shared
        private var isUpdating = false

        init(_ parent: HighlightedTextEditor) {
            self.parent = parent
        }

        func scrollToPosition(_ position: Int) {
            guard let textView = textView else { return }
            let text = textView.string
            let safePosition = min(position, text.count)
            let range = NSRange(location: safePosition, length: 0)
            textView.setSelectedRange(range)
            textView.scrollRangeToVisible(range)
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = textView, !isUpdating else { return }
            parent.text = textView.string
            updateLineCount()
            applySyntaxHighlighting(language: parent.language, isDarkMode: parent.isDarkMode)
        }

        func applySyntaxHighlighting(language: SyntaxLanguage, isDarkMode: Bool) {
            guard let textView = textView, !textView.string.isEmpty else { return }

            isUpdating = true
            defer { isUpdating = false }

            let text = textView.string
            let selectedRanges = textView.selectedRanges
            let scrollPosition = scrollView?.contentView.bounds.origin ?? .zero

            let attributedString = highlighter.highlight(
                text: text,
                language: language,
                isDarkMode: isDarkMode
            )

            textView.textStorage?.setAttributedString(attributedString)

            // Restore selection and scroll
            textView.selectedRanges = selectedRanges
            scrollView?.contentView.scroll(to: scrollPosition)
        }

        func updateLineCount() {
            guard let textView = textView else { return }
            let text = textView.string
            let lineCount = text.isEmpty ? 1 : text.components(separatedBy: .newlines).count
            parent.onLineCountChange(lineCount)
        }

        @objc func scrollViewDidScroll(_ notification: Notification) {
            guard let scrollView = scrollView else { return }
            let offset = scrollView.contentView.bounds.origin.y
            parent.onScrollChange(offset)
        }
    }
}

// MARK: - Custom Text View

class TamgaTextView: NSTextView {
    override init(frame frameRect: NSRect, textContainer container: NSTextContainer?) {
        super.init(frame: frameRect, textContainer: container)
        setupNotifications()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupNotifications()
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupNotifications()
    }

    private func setupNotifications() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleDuplicateLine),
            name: .duplicateLine,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleMoveLineUp),
            name: .moveLineUp,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleMoveLineDown),
            name: .moveLineDown,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleSortLinesAscending),
            name: .sortLinesAscending,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleSortLinesDescending),
            name: .sortLinesDescending,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleRemoveDuplicateLines),
            name: .removeDuplicateLines,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleUppercase),
            name: .uppercaseSelection,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleLowercase),
            name: .lowercaseSelection,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleCapitalize),
            name: .capitalizeSelection,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleFormatJSON),
            name: .formatJSON,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleMinifyJSON),
            name: .minifyJSON,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleFoldCode),
            name: .foldCode,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleUnfoldCode),
            name: .unfoldCode,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleFoldAll),
            name: .foldAll,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleUnfoldAll),
            name: .unfoldAll,
            object: nil
        )
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - Code Folding Storage

    private struct FoldedRegion {
        let range: NSRange
        let originalText: String
        let placeholder: String
    }

    private static var foldedRegions: [NSTextView: [FoldedRegion]] = [:]

    private var myFoldedRegions: [FoldedRegion] {
        get { TamgaTextView.foldedRegions[self] ?? [] }
        set { TamgaTextView.foldedRegions[self] = newValue }
    }

    // MARK: - Sort & Transform Handlers

    @objc private func handleSortLinesAscending() {
        guard window?.firstResponder === self else { return }
        sortLines(ascending: true)
    }

    @objc private func handleSortLinesDescending() {
        guard window?.firstResponder === self else { return }
        sortLines(ascending: false)
    }

    @objc private func handleRemoveDuplicateLines() {
        guard window?.firstResponder === self else { return }
        removeDuplicateLines()
    }

    @objc private func handleUppercase() {
        guard window?.firstResponder === self else { return }
        changeCase(.uppercase)
    }

    @objc private func handleLowercase() {
        guard window?.firstResponder === self else { return }
        changeCase(.lowercase)
    }

    @objc private func handleCapitalize() {
        guard window?.firstResponder === self else { return }
        changeCase(.capitalize)
    }

    @objc private func handleFormatJSON() {
        guard window?.firstResponder === self else { return }
        formatJSON(minify: false)
    }

    @objc private func handleMinifyJSON() {
        guard window?.firstResponder === self else { return }
        formatJSON(minify: true)
    }

    @objc private func handleDuplicateLine() {
        guard window?.firstResponder === self else { return }
        duplicateCurrentLine()
    }

    @objc private func handleMoveLineUp() {
        guard window?.firstResponder === self else { return }
        moveCurrentLineUp()
    }

    @objc private func handleMoveLineDown() {
        guard window?.firstResponder === self else { return }
        moveCurrentLineDown()
    }

    // MARK: - Auto-indent

    override func insertNewline(_ sender: Any?) {
        let text = string
        let cursorPos = selectedRange().location

        // Find the current line content before cursor
        let lines = text.components(separatedBy: "\n")
        var currentPos = 0
        var lineContent = ""

        for line in lines {
            let lineEnd = currentPos + line.count
            if cursorPos <= lineEnd {
                // Get the part of the line before cursor
                let cursorOffsetInLine = cursorPos - currentPos
                let endIndex = line.index(line.startIndex, offsetBy: min(cursorOffsetInLine, line.count))
                lineContent = String(line[line.startIndex..<endIndex])
                break
            }
            currentPos = lineEnd + 1 // +1 for newline
        }

        // Calculate current indentation
        var indentation = ""
        for char in lineContent {
            if char == " " || char == "\t" {
                indentation.append(char)
            } else {
                break
            }
        }

        // Check if line ends with opening bracket or colon (for languages like Python)
        let trimmedLine = lineContent.trimmingCharacters(in: CharacterSet.whitespaces)
        let shouldAddExtraIndent = trimmedLine.hasSuffix("{") ||
                                   trimmedLine.hasSuffix(":") ||
                                   trimmedLine.hasSuffix("(") ||
                                   trimmedLine.hasSuffix("[")

        if shouldAddExtraIndent {
            // Use tabs or 4 spaces based on existing indentation style
            let indentChar = indentation.contains("\t") ? "\t" : "    "
            indentation += indentChar
        }

        // Insert newline with indentation
        super.insertNewline(sender)
        insertText(indentation, replacementRange: selectedRange())
    }

    override func insertTab(_ sender: Any?) {
        // Insert 4 spaces instead of tab for consistency
        insertText("    ", replacementRange: selectedRange())
    }

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        // Allow standard shortcuts
        if event.modifierFlags.contains(.command) {
            let hasOption = event.modifierFlags.contains(.option)

            switch event.charactersIgnoringModifiers {
            case "a": // Select All
                selectAll(nil)
                return true
            case "z" where event.modifierFlags.contains(.shift): // Redo
                undoManager?.redo()
                return true
            case "z": // Undo
                undoManager?.undo()
                return true
            case "d" where !hasOption: // Duplicate Line
                duplicateCurrentLine()
                return true
            default:
                break
            }
        }

        // Move line up/down with Option+Up/Down
        if event.modifierFlags.contains(.option) {
            switch event.keyCode {
            case 126: // Up arrow
                moveCurrentLineUp()
                return true
            case 125: // Down arrow
                moveCurrentLineDown()
                return true
            default:
                break
            }
        }

        return super.performKeyEquivalent(with: event)
    }

    private func duplicateCurrentLine() {
        let text = string
        let cursorPos = selectedRange().location
        let lines = text.components(separatedBy: "\n")

        // Find which line the cursor is on
        var currentPos = 0
        var lineIndex = 0
        for (index, line) in lines.enumerated() {
            let lineEnd = currentPos + line.count
            if cursorPos <= lineEnd || index == lines.count - 1 {
                lineIndex = index
                break
            }
            currentPos = lineEnd + 1
        }

        // Duplicate the line
        var newLines = lines
        newLines.insert(lines[lineIndex], at: lineIndex + 1)

        let newContent = newLines.joined(separator: "\n")

        // Calculate new cursor position
        var newCursorPos = 0
        for i in 0...lineIndex {
            newCursorPos += lines[i].count + 1
        }

        // Update text
        string = newContent
        setSelectedRange(NSRange(location: newCursorPos, length: 0))

        // Notify delegate of change
        delegate?.textDidChange?(Notification(name: NSText.didChangeNotification, object: self))
    }

    private func moveCurrentLineUp() {
        moveCurrentLine(direction: .up)
    }

    private func moveCurrentLineDown() {
        moveCurrentLine(direction: .down)
    }

    private func moveCurrentLine(direction: MoveDirection) {
        let text = string
        let cursorPos = selectedRange().location
        let lines = text.components(separatedBy: "\n")

        // Find which line the cursor is on
        var currentPos = 0
        var lineIndex = 0
        var cursorOffsetInLine = 0
        for (index, line) in lines.enumerated() {
            let lineEnd = currentPos + line.count
            if cursorPos <= lineEnd || index == lines.count - 1 {
                lineIndex = index
                cursorOffsetInLine = cursorPos - currentPos
                break
            }
            currentPos = lineEnd + 1
        }

        // Check if move is valid
        let targetIndex: Int
        switch direction {
        case .up:
            guard lineIndex > 0 else { return }
            targetIndex = lineIndex - 1
        case .down:
            guard lineIndex < lines.count - 1 else { return }
            targetIndex = lineIndex + 1
        }

        // Swap lines
        var newLines = lines
        let temp = newLines[lineIndex]
        newLines[lineIndex] = newLines[targetIndex]
        newLines[targetIndex] = temp

        let newContent = newLines.joined(separator: "\n")

        // Calculate new cursor position
        var newCursorPos = 0
        for i in 0..<targetIndex {
            newCursorPos += newLines[i].count + 1
        }
        newCursorPos += min(cursorOffsetInLine, newLines[targetIndex].count)

        // Update text
        string = newContent
        setSelectedRange(NSRange(location: newCursorPos, length: 0))

        // Notify delegate of change
        delegate?.textDidChange?(Notification(name: NSText.didChangeNotification, object: self))
    }

    private enum MoveDirection {
        case up
        case down
    }

    // MARK: - Sort Lines

    private func sortLines(ascending: Bool) {
        let text = string
        let selectedRange = self.selectedRange()

        // If there's a selection, sort only selected lines
        // Otherwise sort all lines
        if selectedRange.length > 0 {
            // Get selected text and sort it
            let nsString = text as NSString
            let selectedText = nsString.substring(with: selectedRange)
            var lines = selectedText.components(separatedBy: "\n")
            lines = ascending ? lines.sorted() : lines.sorted().reversed()
            let sortedText = lines.joined(separator: "\n")

            // Replace selected text
            if let textStorage = self.textStorage {
                textStorage.replaceCharacters(in: selectedRange, with: sortedText)
                setSelectedRange(NSRange(location: selectedRange.location, length: sortedText.count))
            }
        } else {
            // Sort all lines
            var lines = text.components(separatedBy: "\n")
            lines = ascending ? lines.sorted() : lines.sorted().reversed()
            let newContent = lines.joined(separator: "\n")

            string = newContent
            setSelectedRange(NSRange(location: 0, length: 0))
        }

        delegate?.textDidChange?(Notification(name: NSText.didChangeNotification, object: self))
    }

    // MARK: - Remove Duplicate Lines

    private func removeDuplicateLines() {
        let text = string
        let lines = text.components(separatedBy: "\n")

        var seen = Set<String>()
        var uniqueLines: [String] = []

        for line in lines {
            if !seen.contains(line) {
                seen.insert(line)
                uniqueLines.append(line)
            }
        }

        let newContent = uniqueLines.joined(separator: "\n")
        string = newContent
        setSelectedRange(NSRange(location: 0, length: 0))

        delegate?.textDidChange?(Notification(name: NSText.didChangeNotification, object: self))
    }

    // MARK: - Change Case

    private enum CaseType {
        case uppercase
        case lowercase
        case capitalize
    }

    private func changeCase(_ caseType: CaseType) {
        let selectedRange = self.selectedRange()

        guard selectedRange.length > 0 else { return }

        let nsString = string as NSString
        let selectedText = nsString.substring(with: selectedRange)

        let transformedText: String
        switch caseType {
        case .uppercase:
            transformedText = selectedText.uppercased()
        case .lowercase:
            transformedText = selectedText.lowercased()
        case .capitalize:
            transformedText = selectedText.capitalized
        }

        if let textStorage = self.textStorage {
            textStorage.replaceCharacters(in: selectedRange, with: transformedText)
            setSelectedRange(NSRange(location: selectedRange.location, length: transformedText.count))
        }

        delegate?.textDidChange?(Notification(name: NSText.didChangeNotification, object: self))
    }

    // MARK: - JSON Formatting

    private func formatJSON(minify: Bool) {
        let text = string
        let selectedRange = self.selectedRange()

        // Determine text to format (selection or entire document)
        let textToFormat: String
        let rangeToReplace: NSRange

        if selectedRange.length > 0 {
            let nsString = text as NSString
            textToFormat = nsString.substring(with: selectedRange)
            rangeToReplace = selectedRange
        } else {
            textToFormat = text
            rangeToReplace = NSRange(location: 0, length: text.count)
        }

        // Try to parse and format JSON
        guard let jsonData = textToFormat.data(using: .utf8),
              let jsonObject = try? JSONSerialization.jsonObject(with: jsonData, options: .fragmentsAllowed) else {
            // Invalid JSON - beep
            NSSound.beep()
            return
        }

        let formattedData: Data?
        if minify {
            formattedData = try? JSONSerialization.data(withJSONObject: jsonObject, options: .fragmentsAllowed)
        } else {
            formattedData = try? JSONSerialization.data(withJSONObject: jsonObject, options: [.prettyPrinted, .sortedKeys, .fragmentsAllowed])
        }

        guard let data = formattedData,
              let formattedString = String(data: data, encoding: .utf8) else {
            NSSound.beep()
            return
        }

        // Replace text
        if let textStorage = self.textStorage {
            textStorage.replaceCharacters(in: rangeToReplace, with: formattedString)
            if selectedRange.length > 0 {
                setSelectedRange(NSRange(location: rangeToReplace.location, length: formattedString.count))
            } else {
                setSelectedRange(NSRange(location: 0, length: 0))
            }
        }

        delegate?.textDidChange?(Notification(name: NSText.didChangeNotification, object: self))
    }

    // MARK: - Code Folding Handlers

    @objc private func handleFoldCode() {
        guard window?.firstResponder === self else { return }
        foldCurrentBlock()
    }

    @objc private func handleUnfoldCode() {
        guard window?.firstResponder === self else { return }
        unfoldAtCursor()
    }

    @objc private func handleFoldAll() {
        guard window?.firstResponder === self else { return }
        foldAllBlocks()
    }

    @objc private func handleUnfoldAll() {
        guard window?.firstResponder === self else { return }
        unfoldAllBlocks()
    }

    // MARK: - Code Folding Implementation

    private func foldCurrentBlock() {
        let text = string
        let cursorPos = selectedRange().location

        // Find the opening brace before or at cursor
        guard let blockRange = findBlockRange(in: text, around: cursorPos) else {
            NSSound.beep()
            return
        }

        // Extract the content to fold
        let nsString = text as NSString
        let blockContent = nsString.substring(with: blockRange)

        // Create placeholder showing first line and "..."
        let firstLine = blockContent.components(separatedBy: "\n").first ?? ""
        let placeholder = "\(firstLine) ... }"

        // Store the folded region
        let region = FoldedRegion(range: blockRange, originalText: blockContent, placeholder: placeholder)
        myFoldedRegions.append(region)

        // Replace with placeholder
        if let textStorage = self.textStorage {
            textStorage.replaceCharacters(in: blockRange, with: placeholder)

            // Add special formatting to indicate folded region
            let placeholderRange = NSRange(location: blockRange.location, length: placeholder.count)
            textStorage.addAttribute(.backgroundColor, value: NSColor.systemGray.withAlphaComponent(0.2), range: placeholderRange)
            textStorage.addAttribute(.toolTip, value: "Click to unfold", range: placeholderRange)
        }

        delegate?.textDidChange?(Notification(name: NSText.didChangeNotification, object: self))
    }

    private func unfoldAtCursor() {
        let cursorPos = selectedRange().location

        // Find if cursor is on a folded region
        for (index, region) in myFoldedRegions.enumerated() {
            // Adjust for any previous unfolds
            let adjustedStart = region.range.location
            let adjustedEnd = adjustedStart + region.placeholder.count

            if cursorPos >= adjustedStart && cursorPos <= adjustedEnd {
                // Found folded region - unfold it
                let currentRange = NSRange(location: adjustedStart, length: region.placeholder.count)

                if let textStorage = self.textStorage {
                    textStorage.replaceCharacters(in: currentRange, with: region.originalText)
                }

                myFoldedRegions.remove(at: index)
                delegate?.textDidChange?(Notification(name: NSText.didChangeNotification, object: self))
                return
            }
        }

        NSSound.beep()
    }

    private func foldAllBlocks() {
        let text = string
        var offset = 0
        var index = text.startIndex

        while index < text.endIndex {
            let char = text[index]
            if char == "{" {
                let position = text.distance(from: text.startIndex, to: index)
                if let blockRange = findBlockRange(in: string, around: position + offset) {
                    let nsString = string as NSString
                    let blockContent = nsString.substring(with: blockRange)

                    let firstLine = blockContent.components(separatedBy: "\n").first ?? ""
                    let placeholder = "\(firstLine) ... }"

                    let region = FoldedRegion(range: blockRange, originalText: blockContent, placeholder: placeholder)
                    myFoldedRegions.append(region)

                    if let textStorage = self.textStorage {
                        textStorage.replaceCharacters(in: blockRange, with: placeholder)
                        let placeholderRange = NSRange(location: blockRange.location, length: placeholder.count)
                        textStorage.addAttribute(.backgroundColor, value: NSColor.systemGray.withAlphaComponent(0.2), range: placeholderRange)
                    }

                    offset -= (blockRange.length - placeholder.count)
                }
            }
            index = text.index(after: index)
        }

        delegate?.textDidChange?(Notification(name: NSText.didChangeNotification, object: self))
    }

    private func unfoldAllBlocks() {
        // Unfold in reverse order to maintain correct positions
        for region in myFoldedRegions.reversed() {
            let currentRange = NSRange(location: region.range.location, length: region.placeholder.count)

            if let textStorage = self.textStorage {
                textStorage.replaceCharacters(in: currentRange, with: region.originalText)
            }
        }

        myFoldedRegions.removeAll()
        delegate?.textDidChange?(Notification(name: NSText.didChangeNotification, object: self))
    }

    private func findBlockRange(in text: String, around position: Int) -> NSRange? {
        // Find the opening brace
        var openBracePos = position
        var foundOpenBrace = false

        // Search backwards for opening brace if not at one
        let chars = Array(text)
        if position < chars.count && chars[position] == "{" {
            foundOpenBrace = true
        } else {
            var searchPos = min(position, chars.count - 1)
            while searchPos >= 0 {
                if chars[searchPos] == "{" {
                    openBracePos = searchPos
                    foundOpenBrace = true
                    break
                }
                searchPos -= 1
            }
        }

        guard foundOpenBrace else { return nil }

        // Find matching closing brace
        var braceCount = 1
        var closeBracePos = openBracePos + 1

        while closeBracePos < chars.count && braceCount > 0 {
            if chars[closeBracePos] == "{" {
                braceCount += 1
            } else if chars[closeBracePos] == "}" {
                braceCount -= 1
            }
            closeBracePos += 1
        }

        guard braceCount == 0 else { return nil }

        // Find the start of the line containing the opening brace
        var lineStart = openBracePos
        while lineStart > 0 && chars[lineStart - 1] != "\n" {
            lineStart -= 1
        }

        return NSRange(location: lineStart, length: closeBracePos - lineStart)
    }
}

#Preview {
    EditorView(
        text: .constant("func hello() {\n    print(\"Hello, World!\")\n}"),
        language: .swift,
        showLineNumbers: true,
        isWordWrapEnabled: true,
        fontSize: 14,
        fontName: "SF Mono"
    )
    .frame(width: 600, height: 400)
}
