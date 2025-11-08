import Foundation
import AppKit

/// Represents a text selection in the terminal grid
struct Selection {
    var start: GridPosition
    var end: GridPosition
    var mode: SelectionMode

    enum SelectionMode {
        case character  // Character-by-character selection
        case word       // Word-based selection (double-click)
        case line       // Line-based selection (triple-click)
        case block      // Rectangular block selection (Alt+drag)
    }

    /// Get normalized selection (start always before end)
    var normalized: (start: GridPosition, end: GridPosition) {
        if start.row < end.row || (start.row == end.row && start.col <= end.col) {
            return (start, end)
        } else {
            return (end, start)
        }
    }

    /// Check if selection contains a position
    func contains(_ pos: GridPosition) -> Bool {
        let norm = normalized

        switch mode {
        case .character, .word, .line:
            // Standard selection
            if pos.row < norm.start.row || pos.row > norm.end.row {
                return false
            }
            if pos.row == norm.start.row && pos.col < norm.start.col {
                return false
            }
            if pos.row == norm.end.row && pos.col > norm.end.col {
                return false
            }
            return true

        case .block:
            // Rectangular block selection
            let minRow = min(start.row, end.row)
            let maxRow = max(start.row, end.row)
            let minCol = min(start.col, end.col)
            let maxCol = max(start.col, end.col)

            return pos.row >= minRow && pos.row <= maxRow &&
                   pos.col >= minCol && pos.col <= maxCol
        }
    }
}

/// Position in terminal grid
struct GridPosition: Equatable {
    var row: Int
    var col: Int
}

/// Manages text selection in the terminal
class TextSelectionManager {
    // MARK: - Properties

    private(set) var selection: Selection?
    private var isDragging = false
    private var dragStart: GridPosition?

    // Configuration
    var enabled: Bool = true
    var allowBlockSelection: Bool = true  // Alt+drag for block selection

    // MARK: - Selection API

    /// Start a new selection
    func startSelection(at position: GridPosition, mode: Selection.SelectionMode = .character) {
        selection = Selection(start: position, end: position, mode: mode)
        isDragging = true
        dragStart = position
    }

    /// Update selection endpoint (during drag)
    func updateSelection(to position: GridPosition) {
        guard var sel = selection else { return }
        sel.end = position
        selection = sel
    }

    /// End selection (mouse up)
    func endSelection() {
        isDragging = false

        // Clear selection if it's just a click (no drag)
        if let sel = selection, sel.start == sel.end {
            selection = nil
        }
    }

    /// Clear current selection
    func clearSelection() {
        selection = nil
        isDragging = false
        dragStart = nil
    }

    /// Check if actively selecting
    var isSelecting: Bool {
        return isDragging
    }

    /// Check if there's an active selection
    var hasSelection: Bool {
        return selection != nil
    }

    // MARK: - Word/Line Selection

    /// Expand selection to word boundaries
    func expandToWord(in text: String, at position: GridPosition) {
        guard !text.isEmpty else { return }

        // Find word boundaries
        var startCol = position.col
        var endCol = position.col

        let chars = Array(text)

        // Expand left
        while startCol > 0 && isWordChar(chars[startCol - 1]) {
            startCol -= 1
        }

        // Expand right
        while endCol < chars.count - 1 && isWordChar(chars[endCol + 1]) {
            endCol += 1
        }

        selection = Selection(
            start: GridPosition(row: position.row, col: startCol),
            end: GridPosition(row: position.row, col: endCol),
            mode: .word
        )
    }

    /// Select entire line
    func selectLine(at position: GridPosition, lineLength: Int) {
        selection = Selection(
            start: GridPosition(row: position.row, col: 0),
            end: GridPosition(row: position.row, col: lineLength - 1),
            mode: .line
        )
    }

    private func isWordChar(_ char: Character) -> Bool {
        return char.isLetter || char.isNumber || char == "_" || char == "-"
    }

    // MARK: - Text Extraction

    /// Extract selected text from terminal
    func getSelectedText(from terminal: TerminalCore) -> String? {
        guard let sel = selection else { return nil }

        let norm = sel.normalized
        var text = ""

        switch sel.mode {
        case .character, .word, .line:
            // Standard selection - copy continuous text
            for row in norm.start.row...norm.end.row {
                guard let rowData = terminal.getRow(row) else { continue }

                let startCol = (row == norm.start.row) ? norm.start.col : 0
                let endCol = (row == norm.end.row) ? norm.end.col : rowData.count - 1

                for col in startCol...min(endCol, rowData.count - 1) {
                    let cell = rowData[col]
                    if let scalar = UnicodeScalar(cell.ch) {
                        text.append(Character(scalar))
                    }
                }

                // Add newline between rows (except last)
                if row < norm.end.row {
                    text.append("\n")
                }
            }

        case .block:
            // Block selection - copy rectangular region
            let minRow = min(sel.start.row, sel.end.row)
            let maxRow = max(sel.start.row, sel.end.row)
            let minCol = min(sel.start.col, sel.end.col)
            let maxCol = max(sel.start.col, sel.end.col)

            for row in minRow...maxRow {
                guard let rowData = terminal.getRow(row) else { continue }

                for col in minCol...min(maxCol, rowData.count - 1) {
                    let cell = rowData[col]
                    if let scalar = UnicodeScalar(cell.ch) {
                        text.append(Character(scalar))
                    }
                }

                if row < maxRow {
                    text.append("\n")
                }
            }
        }

        return text.isEmpty ? nil : text
    }

    // MARK: - Rendering Support

    /// Get all selected positions for rendering highlights
    func getSelectedPositions() -> Set<GridPosition>? {
        guard let sel = selection else { return nil }

        var positions = Set<GridPosition>()
        let norm = sel.normalized

        switch sel.mode {
        case .character, .word, .line:
            for row in norm.start.row...norm.end.row {
                let startCol = (row == norm.start.row) ? norm.start.col : 0
                let endCol = (row == norm.end.row) ? norm.end.col : Int.max

                for col in startCol...endCol {
                    positions.insert(GridPosition(row: row, col: col))
                }
            }

        case .block:
            let minRow = min(sel.start.row, sel.end.row)
            let maxRow = max(sel.start.row, sel.end.row)
            let minCol = min(sel.start.col, sel.end.col)
            let maxCol = max(sel.start.col, sel.end.col)

            for row in minRow...maxRow {
                for col in minCol...maxCol {
                    positions.insert(GridPosition(row: row, col: col))
                }
            }
        }

        return positions
    }
}

// MARK: - GridPosition Hashable

extension GridPosition: Hashable {
    func hash(into hasher: inout Hasher) {
        hasher.combine(row)
        hasher.combine(col)
    }
}

// MARK: - Mouse Event Helper

extension TextSelectionManager {
    /// Handle mouse down event
    func handleMouseDown(at point: CGPoint, cellWidth: CGFloat, cellHeight: CGFloat,
                        clickCount: Int, modifierFlags: NSEvent.ModifierFlags,
                        terminal: TerminalCore) {
        guard enabled else { return }

        let col = Int(point.x / cellWidth)
        let row = Int(point.y / cellHeight)
        let position = GridPosition(row: row, col: col)

        // Determine selection mode
        if modifierFlags.contains(.option) && allowBlockSelection {
            // Block selection with Alt/Option key
            startSelection(at: position, mode: .block)
        } else if clickCount == 2 {
            // Double-click: word selection
            if let rowData = terminal.getRow(row), col < rowData.count {
                let text = rowData.map { String(UnicodeScalar($0.ch) ?? " ") }.joined()
                expandToWord(in: text, at: position)
            }
        } else if clickCount == 3 {
            // Triple-click: line selection
            if let rowData = terminal.getRow(row) {
                selectLine(at: position, lineLength: rowData.count)
            }
        } else {
            // Single click: character selection
            startSelection(at: position, mode: .character)
        }
    }

    /// Handle mouse drag event
    func handleMouseDragged(to point: CGPoint, cellWidth: CGFloat, cellHeight: CGFloat) {
        guard enabled && isSelecting else { return }

        let col = Int(point.x / cellWidth)
        let row = Int(point.y / cellHeight)
        let position = GridPosition(row: row, col: col)

        updateSelection(to: position)
    }

    /// Handle mouse up event
    func handleMouseUp() {
        endSelection()
    }
}
