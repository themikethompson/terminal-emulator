import Foundation
import AppKit

/// Manages search functionality in the terminal
class SearchManager {
    // MARK: - Types

    struct SearchResult {
        let row: Int
        let col: Int
        let length: Int
        let text: String
    }

    enum SearchMode {
        case plainText
        case regex
        case wholeWord
    }

    // MARK: - Properties

    private(set) var searchQuery: String = ""
    private(set) var searchMode: SearchMode = .plainText
    private(set) var caseSensitive: Bool = false
    private(set) var results: [SearchResult] = []
    private(set) var currentResultIndex: Int = -1

    var hasResults: Bool {
        return !results.isEmpty
    }

    var currentResult: SearchResult? {
        guard currentResultIndex >= 0 && currentResultIndex < results.count else { return nil }
        return results[currentResultIndex]
    }

    // MARK: - Search Operations

    /// Perform search in terminal
    func search(query: String, in terminal: TerminalCore, mode: SearchMode = .plainText,
                caseSensitive: Bool = false) {
        self.searchQuery = query
        self.searchMode = mode
        self.caseSensitive = caseSensitive
        self.results = []
        self.currentResultIndex = -1

        guard !query.isEmpty else { return }

        // Search through all visible rows
        for row in 0..<Int(terminal.rows) {
            guard let rowData = terminal.getRow(row) else { continue }

            let rowText = rowData.map { String(UnicodeScalar($0.ch) ?? " ") }.joined()

            switch mode {
            case .plainText:
                searchPlainText(query: query, in: rowText, row: row)

            case .regex:
                searchRegex(pattern: query, in: rowText, row: row)

            case .wholeWord:
                searchWholeWord(query: query, in: rowText, row: row)
            }
        }

        // Select first result if any
        if !results.isEmpty {
            currentResultIndex = 0
        }
    }

    private func searchPlainText(query: String, in text: String, row: Int) {
        let searchText = caseSensitive ? text : text.lowercased()
        let searchQuery = caseSensitive ? query : query.lowercased()

        var startIndex = searchText.startIndex

        while let range = searchText[startIndex...].range(of: searchQuery) {
            let col = searchText.distance(from: searchText.startIndex, to: range.lowerBound)

            results.append(SearchResult(
                row: row,
                col: col,
                length: query.count,
                text: String(text[range])
            ))

            startIndex = searchText.index(after: range.lowerBound)

            if startIndex >= searchText.endIndex {
                break
            }
        }
    }

    private func searchRegex(pattern: String, in text: String, row: Int) {
        do {
            let options: NSRegularExpression.Options = caseSensitive ? [] : .caseInsensitive
            let regex = try NSRegularExpression(pattern: pattern, options: options)

            let nsText = text as NSString
            let matches = regex.matches(in: text, range: NSRange(location: 0, length: nsText.length))

            for match in matches {
                let range = match.range
                let col = range.location

                results.append(SearchResult(
                    row: row,
                    col: col,
                    length: range.length,
                    text: nsText.substring(with: range)
                ))
            }
        } catch {
            print("Invalid regex pattern: \(error)")
        }
    }

    private func searchWholeWord(query: String, in text: String, row: Int) {
        let searchText = caseSensitive ? text : text.lowercased()
        let searchQuery = caseSensitive ? query : query.lowercased()

        var startIndex = searchText.startIndex

        while let range = searchText[startIndex...].range(of: searchQuery) {
            let col = searchText.distance(from: searchText.startIndex, to: range.lowerBound)

            // Check if it's a whole word (bounded by non-word characters)
            let beforeIndex = range.lowerBound
            let afterIndex = range.upperBound

            let beforeIsWordBoundary = beforeIndex == searchText.startIndex ||
                                      !searchText[searchText.index(before: beforeIndex)].isLetter

            let afterIsWordBoundary = afterIndex == searchText.endIndex ||
                                     !searchText[afterIndex].isLetter

            if beforeIsWordBoundary && afterIsWordBoundary {
                results.append(SearchResult(
                    row: row,
                    col: col,
                    length: query.count,
                    text: String(text[range])
                ))
            }

            startIndex = searchText.index(after: range.lowerBound)

            if startIndex >= searchText.endIndex {
                break
            }
        }
    }

    // MARK: - Navigation

    /// Go to next search result
    func nextResult() {
        guard !results.isEmpty else { return }
        currentResultIndex = (currentResultIndex + 1) % results.count
    }

    /// Go to previous search result
    func previousResult() {
        guard !results.isEmpty else { return }

        if currentResultIndex <= 0 {
            currentResultIndex = results.count - 1
        } else {
            currentResultIndex -= 1
        }
    }

    /// Clear search
    func clearSearch() {
        searchQuery = ""
        results = []
        currentResultIndex = -1
    }

    // MARK: - Incremental Search

    /// Update search incrementally (as user types)
    func incrementalSearch(query: String, in terminal: TerminalCore) {
        search(query: query, in: terminal, mode: searchMode, caseSensitive: caseSensitive)
    }

    // MARK: - Search UI Support

    /// Get search status text
    func getStatusText() -> String {
        if searchQuery.isEmpty {
            return ""
        }

        if results.isEmpty {
            return "No results for '\(searchQuery)'"
        }

        return "Result \(currentResultIndex + 1) of \(results.count)"
    }

    /// Get all result positions for highlighting
    func getAllResultPositions() -> [(row: Int, col: Int, length: Int)] {
        return results.map { ($0.row, $0.col, $0.length) }
    }
}

// MARK: - Search Panel

/// A simple search panel view
class SearchPanel: NSView {
    // UI Components
    private let searchField = NSSearchField()
    private let resultLabel = NSTextField(labelWithString: "")
    private let previousButton = NSButton()
    private let nextButton = NSButton()
    private let caseToggle = NSButton(checkboxWithTitle: "Case Sensitive", target: nil, action: nil)
    private let regexToggle = NSButton(checkboxWithTitle: "Regex", target: nil, action: nil)
    private let closeButton = NSButton()

    var onSearchChanged: ((String) -> Void)?
    var onNext: (() -> Void)?
    var onPrevious: (() -> Void)?
    var onClose: (() -> Void)?
    var onCaseToggled: ((Bool) -> Void)?
    var onRegexToggled: ((Bool) -> Void)?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupUI()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUI()
    }

    private func setupUI() {
        // Configure search field
        searchField.placeholderString = "Search..."
        searchField.target = self
        searchField.action = #selector(searchFieldChanged)

        // Configure buttons
        previousButton.title = "◀"
        previousButton.target = self
        previousButton.action = #selector(previousButtonClicked)

        nextButton.title = "▶"
        nextButton.target = self
        nextButton.action = #selector(nextButtonClicked)

        closeButton.title = "✕"
        closeButton.target = self
        closeButton.action = #selector(closeButtonClicked)

        // Configure toggles
        caseToggle.target = self
        caseToggle.action = #selector(caseToggleChanged)

        regexToggle.target = self
        regexToggle.action = #selector(regexToggleChanged)

        // Layout (simplified - would use Auto Layout in production)
        addSubview(searchField)
        addSubview(resultLabel)
        addSubview(previousButton)
        addSubview(nextButton)
        addSubview(caseToggle)
        addSubview(regexToggle)
        addSubview(closeButton)

        // Simple layout
        searchField.frame = NSRect(x: 10, y: 10, width: 200, height: 24)
        previousButton.frame = NSRect(x: 220, y: 10, width: 30, height: 24)
        nextButton.frame = NSRect(x: 255, y: 10, width: 30, height: 24)
        resultLabel.frame = NSRect(x: 295, y: 10, width: 150, height: 24)
        caseToggle.frame = NSRect(x: 455, y: 10, width: 120, height: 24)
        regexToggle.frame = NSRect(x: 585, y: 10, width: 80, height: 24)
        closeButton.frame = NSRect(x: 675, y: 10, width: 30, height: 24)
    }

    @objc private func searchFieldChanged() {
        onSearchChanged?(searchField.stringValue)
    }

    @objc private func previousButtonClicked() {
        onPrevious?()
    }

    @objc private func nextButtonClicked() {
        onNext?()
    }

    @objc private func closeButtonClicked() {
        onClose?()
    }

    @objc private func caseToggleChanged() {
        onCaseToggled?(caseToggle.state == .on)
    }

    @objc private func regexToggleChanged() {
        onRegexToggled?(regexToggle.state == .on)
    }

    func updateStatus(_ text: String) {
        resultLabel.stringValue = text
    }

    func focusSearchField() {
        window?.makeFirstResponder(searchField)
    }
}
