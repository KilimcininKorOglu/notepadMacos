import SwiftUI

/// Status bar showing document information
struct StatusBarView: View {
    let documentInfo: DocumentInfo
    let language: SyntaxLanguage
    let encoding: String
    let onLanguageChange: (SyntaxLanguage) -> Void

    var body: some View {
        HStack(spacing: 16) {
            // Line and column
            HStack(spacing: 4) {
                Text(String(localized: "line"))
                Text("\(documentInfo.currentLine)")
                    .fontWeight(.medium)
                Text(",")
                Text(String(localized: "column"))
                Text("\(documentInfo.currentColumn)")
                    .fontWeight(.medium)
            }

            Divider()
                .frame(height: 12)

            // Character count
            HStack(spacing: 4) {
                Text("\(documentInfo.characterCount)")
                    .fontWeight(.medium)
                Text(String(localized: "characters"))
            }

            Divider()
                .frame(height: 12)

            // Word count
            HStack(spacing: 4) {
                Text("\(documentInfo.wordCount)")
                    .fontWeight(.medium)
                Text(String(localized: "words"))
            }

            Spacer()

            // Encoding
            Text(encoding)
                .foregroundColor(.secondary)

            Divider()
                .frame(height: 12)

            // Language selector
            Menu {
                ForEach(SyntaxLanguage.allCases, id: \.self) { lang in
                    Button(lang.displayName) {
                        onLanguageChange(lang)
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Text(language.displayName)
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 8))
                }
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
        }
        .font(.system(size: 11))
        .foregroundColor(.secondary)
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
        .frame(height: 24)
        .background(Color(nsColor: .windowBackgroundColor))
    }
}

#Preview {
    StatusBarView(
        documentInfo: DocumentInfo(content: "Hello World\nThis is a test", cursorPosition: 5),
        language: .swift,
        encoding: "UTF-8",
        onLanguageChange: { _ in }
    )
}
