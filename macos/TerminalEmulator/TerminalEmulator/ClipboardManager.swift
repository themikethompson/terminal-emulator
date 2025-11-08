import AppKit

/// Manages clipboard operations for the terminal
class ClipboardManager {
    // MARK: - Properties

    private let pasteboard = NSPasteboard.general

    // Configuration
    var trimTrailingWhitespace: Bool = true
    var copyWithFormatting: Bool = false  // Future: RTF with colors

    // MARK: - Copy Operations

    /// Copy text to clipboard
    func copy(_ text: String) {
        guard !text.isEmpty else { return }

        var processedText = text

        // Optionally trim trailing whitespace from each line
        if trimTrailingWhitespace {
            processedText = text.split(separator: "\n", omittingEmptySubsequences: false)
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .joined(separator: "\n")
        }

        pasteboard.clearContents()
        pasteboard.setString(processedText, forType: .string)
    }

    /// Copy with formatting (RTF - for future use)
    func copyWithFormat(_ text: String, attributes: [NSAttributedString.Key: Any]) {
        guard !text.isEmpty else { return }

        let attributedString = NSAttributedString(string: text, attributes: attributes)

        pasteboard.clearContents()

        // Add both plain text and RTF
        if let rtfData = try? attributedString.data(from: NSRange(location: 0, length: attributedString.length),
                                                     documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf]) {
            pasteboard.setData(rtfData, forType: .rtf)
        }

        pasteboard.setString(text, forType: .string)
    }

    // MARK: - Paste Operations

    /// Get text from clipboard
    func paste() -> String? {
        return pasteboard.string(forType: .string)
    }

    /// Paste text to terminal (sends to PTY)
    func pasteToTerminal(_ terminal: TerminalCore) {
        guard let text = paste() else { return }

        // Send text to PTY
        _ = terminal.sendInput(text)
    }

    // MARK: - Clipboard History (Future Enhancement)

    private var history: [String] = []
    private let maxHistorySize = 20

    /// Add to clipboard history
    func addToHistory(_ text: String) {
        history.insert(text, at: 0)

        if history.count > maxHistorySize {
            history.removeLast()
        }
    }

    /// Get clipboard history
    func getHistory() -> [String] {
        return history
    }

    // MARK: - Smart Copy Features

    /// Copy and detect URL
    func copyAndDetectURL(_ text: String) -> URL? {
        copy(text)

        // Try to detect if copied text is a URL
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)

        if let url = URL(string: trimmed), url.scheme != nil {
            return url
        }

        return nil
    }

    /// Copy and detect file path
    func copyAndDetectPath(_ text: String) -> String? {
        copy(text)

        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)

        // Check if it looks like a file path
        if trimmed.hasPrefix("/") || trimmed.hasPrefix("~/") {
            return trimmed
        }

        return nil
    }
}

// MARK: - Menu Integration

extension ClipboardManager {
    /// Validate copy menu item
    func validateCopy(hasSelection: Bool) -> Bool {
        return hasSelection
    }

    /// Validate paste menu item
    func validatePaste() -> Bool {
        return pasteboard.string(forType: .string) != nil
    }
}
