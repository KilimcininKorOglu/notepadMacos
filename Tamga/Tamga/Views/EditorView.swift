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
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
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
