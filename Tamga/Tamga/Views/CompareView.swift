import SwiftUI

/// View for comparing two text documents side by side
struct CompareView: View {
    let leftText: String
    let rightText: String
    let leftTitle: String
    let rightTitle: String
    @Binding var isVisible: Bool

    private let diffResult: DiffResult

    init(leftText: String, rightText: String, leftTitle: String, rightTitle: String, isVisible: Binding<Bool>) {
        self.leftText = leftText
        self.rightText = rightText
        self.leftTitle = leftTitle
        self.rightTitle = rightTitle
        self._isVisible = isVisible
        self.diffResult = DiffCalculator.calculate(left: leftText, right: rightText)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text(String(localized: "compare.files"))
                    .font(.headline)

                Spacer()

                // Stats
                HStack(spacing: 16) {
                    Label("\(diffResult.additions)", systemImage: "plus.circle.fill")
                        .foregroundColor(.green)
                    Label("\(diffResult.deletions)", systemImage: "minus.circle.fill")
                        .foregroundColor(.red)
                    Label("\(diffResult.unchanged)", systemImage: "equal.circle.fill")
                        .foregroundColor(.secondary)
                }
                .font(.subheadline)

                Spacer()

                Button {
                    isVisible = false
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding()
            .background(Color(nsColor: .windowBackgroundColor))

            Divider()

            // Side by side comparison
            HSplitView {
                // Left panel
                VStack(spacing: 0) {
                    Text(leftTitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity)
                        .padding(4)
                        .background(Color(nsColor: .controlBackgroundColor))

                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 0) {
                            ForEach(Array(diffResult.leftLines.enumerated()), id: \.offset) { index, line in
                                DiffLineView(line: line, lineNumber: index + 1)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }

                // Right panel
                VStack(spacing: 0) {
                    Text(rightTitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity)
                        .padding(4)
                        .background(Color(nsColor: .controlBackgroundColor))

                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 0) {
                            ForEach(Array(diffResult.rightLines.enumerated()), id: \.offset) { index, line in
                                DiffLineView(line: line, lineNumber: index + 1)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
        }
    }
}

// MARK: - Diff Line View

struct DiffLineView: View {
    let line: DiffLine
    let lineNumber: Int

    var body: some View {
        HStack(spacing: 0) {
            // Line number
            Text("\(lineNumber)")
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(.secondary)
                .frame(width: 40, alignment: .trailing)
                .padding(.trailing, 8)

            // Line content
            Text(line.content.isEmpty ? " " : line.content)
                .font(.system(size: 12, design: .monospaced))
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 2)
        .background(backgroundColor)
    }

    private var backgroundColor: Color {
        switch line.type {
        case .unchanged:
            return Color.clear
        case .added:
            return Color.green.opacity(0.2)
        case .deleted:
            return Color.red.opacity(0.2)
        case .placeholder:
            return Color.gray.opacity(0.1)
        }
    }
}

// MARK: - Diff Models

struct DiffLine: Identifiable {
    let id = UUID()
    let content: String
    let type: DiffType
}

enum DiffType {
    case unchanged
    case added
    case deleted
    case placeholder
}

struct DiffResult {
    let leftLines: [DiffLine]
    let rightLines: [DiffLine]
    let additions: Int
    let deletions: Int
    let unchanged: Int
}

// MARK: - Diff Calculator

struct DiffCalculator {
    static func calculate(left: String, right: String) -> DiffResult {
        let leftLines = left.components(separatedBy: "\n")
        let rightLines = right.components(separatedBy: "\n")

        var resultLeft: [DiffLine] = []
        var resultRight: [DiffLine] = []

        var additions = 0
        var deletions = 0
        var unchanged = 0

        // Simple line-by-line diff using LCS (Longest Common Subsequence)
        let lcs = findLCS(leftLines, rightLines)

        var leftIndex = 0
        var rightIndex = 0
        var lcsIndex = 0

        while leftIndex < leftLines.count || rightIndex < rightLines.count {
            if lcsIndex < lcs.count {
                // Check if current lines match LCS
                let lcsLine = lcs[lcsIndex]

                // Skip deleted lines (in left but not in LCS)
                while leftIndex < leftLines.count && leftLines[leftIndex] != lcsLine {
                    resultLeft.append(DiffLine(content: leftLines[leftIndex], type: .deleted))
                    resultRight.append(DiffLine(content: "", type: .placeholder))
                    deletions += 1
                    leftIndex += 1
                }

                // Skip added lines (in right but not in LCS)
                while rightIndex < rightLines.count && rightLines[rightIndex] != lcsLine {
                    resultLeft.append(DiffLine(content: "", type: .placeholder))
                    resultRight.append(DiffLine(content: rightLines[rightIndex], type: .added))
                    additions += 1
                    rightIndex += 1
                }

                // Add matching line
                if leftIndex < leftLines.count && rightIndex < rightLines.count {
                    resultLeft.append(DiffLine(content: leftLines[leftIndex], type: .unchanged))
                    resultRight.append(DiffLine(content: rightLines[rightIndex], type: .unchanged))
                    unchanged += 1
                    leftIndex += 1
                    rightIndex += 1
                    lcsIndex += 1
                }
            } else {
                // No more LCS matches, remaining lines are deletions or additions
                while leftIndex < leftLines.count {
                    resultLeft.append(DiffLine(content: leftLines[leftIndex], type: .deleted))
                    resultRight.append(DiffLine(content: "", type: .placeholder))
                    deletions += 1
                    leftIndex += 1
                }

                while rightIndex < rightLines.count {
                    resultLeft.append(DiffLine(content: "", type: .placeholder))
                    resultRight.append(DiffLine(content: rightLines[rightIndex], type: .added))
                    additions += 1
                    rightIndex += 1
                }
            }
        }

        return DiffResult(
            leftLines: resultLeft,
            rightLines: resultRight,
            additions: additions,
            deletions: deletions,
            unchanged: unchanged
        )
    }

    // Find Longest Common Subsequence
    private static func findLCS(_ left: [String], _ right: [String]) -> [String] {
        let m = left.count
        let n = right.count

        // DP table
        var dp = Array(repeating: Array(repeating: 0, count: n + 1), count: m + 1)

        for i in 1...m {
            for j in 1...n {
                if left[i - 1] == right[j - 1] {
                    dp[i][j] = dp[i - 1][j - 1] + 1
                } else {
                    dp[i][j] = max(dp[i - 1][j], dp[i][j - 1])
                }
            }
        }

        // Backtrack to find LCS
        var lcs: [String] = []
        var i = m
        var j = n

        while i > 0 && j > 0 {
            if left[i - 1] == right[j - 1] {
                lcs.insert(left[i - 1], at: 0)
                i -= 1
                j -= 1
            } else if dp[i - 1][j] > dp[i][j - 1] {
                i -= 1
            } else {
                j -= 1
            }
        }

        return lcs
    }
}
