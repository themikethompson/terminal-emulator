import Cocoa

class TerminalView: NSView {

    var terminal: TerminalCore?

    // Font and cell dimensions
    private var font: NSFont
    private var cellWidth: CGFloat = 0
    private var cellHeight: CGFloat = 0
    private var baselineOffset: CGFloat = 0

    // Cursor
    private var cursorTimer: Timer?
    private var cursorVisible = true

    override init(frame frameRect: NSRect) {
        // Use a monospace font
        self.font = NSFont.monospacedSystemFont(ofSize: 14, weight: .regular)

        super.init(frame: frameRect)

        calculateCellDimensions()
        setupCursorTimer()
    }

    required init?(coder: NSCoder) {
        self.font = NSFont.monospacedSystemFont(ofSize: 14, weight: .regular)
        super.init(coder: coder)
        calculateCellDimensions()
        setupCursorTimer()
    }

    override var acceptsFirstResponder: Bool {
        return true
    }

    private func calculateCellDimensions() {
        // Measure a sample character to get cell dimensions
        let attributes: [NSAttributedString.Key: Any] = [.font: font]
        let charSize = ("M" as NSString).size(withAttributes: attributes)

        cellWidth = ceil(charSize.width)
        cellHeight = ceil(charSize.height)

        // Calculate baseline offset for proper text positioning
        let fontMetrics = font
        baselineOffset = fontMetrics.ascender
    }

    private func setupCursorTimer() {
        cursorTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.cursorVisible.toggle()
            self?.needsDisplay = true
        }
    }

    func calculateGridSize(for viewSize: NSSize) -> (rows: UInt16, cols: UInt16) {
        let cols = max(1, UInt16(viewSize.width / cellWidth))
        let rows = max(1, UInt16(viewSize.height / cellHeight))
        return (rows, cols)
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        guard let terminal = terminal else { return }
        guard let context = NSGraphicsContext.current?.cgContext else { return }

        // Fill background
        NSColor.black.setFill()
        dirtyRect.fill()

        // Flip coordinate system (CoreGraphics is bottom-left origin)
        context.saveGState()
        context.translateBy(x: 0, y: bounds.height)
        context.scaleBy(x: 1.0, y: -1.0)

        // Draw each row
        for row in 0..<terminal.rows {
            let cells = terminal.getRow(row)
            drawRow(row: Int(row), cells: cells, context: context)
        }

        // Draw cursor
        if cursorVisible {
            drawCursor(context: context)
        }

        context.restoreGState()

        // Mark terminal as clean after rendering
        terminal.markClean()
    }

    private func drawRow(row: Int, cells: [CCell], context: CGContext) {
        let y = CGFloat(row) * cellHeight

        for (col, cell) in cells.enumerated() {
            let x = CGFloat(col) * cellWidth

            // Draw background
            let bgColor = NSColor(
                red: CGFloat(cell.bg_r) / 255.0,
                green: CGFloat(cell.bg_g) / 255.0,
                blue: CGFloat(cell.bg_b) / 255.0,
                alpha: 1.0
            )

            context.setFillColor(bgColor.cgColor)
            context.fill(CGRect(x: x, y: y, width: cellWidth, height: cellHeight))

            // Draw character if not space
            let char = Unicode.Scalar(cell.ch)
            if let scalar = char, scalar != " " {
                let string = String(scalar)
                let fgColor = NSColor(
                    red: CGFloat(cell.fg_r) / 255.0,
                    green: CGFloat(cell.fg_g) / 255.0,
                    blue: CGFloat(cell.fg_b) / 255.0,
                    alpha: 1.0
                )

                // Build attributes with flags
                var attributes: [NSAttributedString.Key: Any] = [
                    .font: font,
                    .foregroundColor: fgColor
                ]

                // Handle text attributes
                if (cell.flags & 0x01) != 0 { // Bold
                    attributes[.font] = NSFont.monospacedSystemFont(ofSize: font.pointSize, weight: .bold)
                }

                if (cell.flags & 0x04) != 0 { // Underline
                    attributes[.underlineStyle] = NSUnderlineStyle.single.rawValue
                }

                // Draw text (need to flip Y coordinate for text)
                let textY = bounds.height - y - cellHeight + (cellHeight - baselineOffset) / 2
                let textRect = CGRect(x: x, y: textY, width: cellWidth, height: cellHeight)

                context.saveGState()
                context.translateBy(x: 0, y: bounds.height)
                context.scaleBy(x: 1.0, y: -1.0)

                (string as NSString).draw(in: textRect, withAttributes: attributes)

                context.restoreGState()
            }
        }
    }

    private func drawCursor(context: CGContext) {
        guard let terminal = terminal else { return }

        let cursor = terminal.cursorPosition
        let x = CGFloat(cursor.col) * cellWidth
        let y = CGFloat(cursor.row) * cellHeight

        // Draw cursor as filled rectangle
        context.setFillColor(NSColor.white.cgColor)
        context.fill(CGRect(x: x, y: y, width: cellWidth, height: cellHeight))
    }

    // MARK: - Keyboard Input

    override func keyDown(with event: NSEvent) {
        guard let terminal = terminal else { return }

        var inputString: String?

        // Handle special keys
        if event.modifierFlags.contains(.command) {
            // Don't intercept Command key combinations (allow Cmd+C, Cmd+V, etc.)
            super.keyDown(with: event)
            return
        }

        // Check for special keys
        if let specialKey = event.specialKey {
            inputString = handleSpecialKey(specialKey, modifiers: event.modifierFlags)
        } else if let characters = event.characters {
            // Handle control key combinations
            if event.modifierFlags.contains(.control) {
                inputString = handleControlKey(characters)
            } else {
                inputString = characters
            }
        }

        if let input = inputString {
            _ = terminal.sendInput(input)
        }
    }

    private func handleSpecialKey(_ key: NSEvent.SpecialKey, modifiers: NSEvent.ModifierFlags) -> String? {
        switch key {
        case .upArrow:
            return "\u{1b}[A"
        case .downArrow:
            return "\u{1b}[B"
        case .rightArrow:
            return "\u{1b}[C"
        case .leftArrow:
            return "\u{1b}[D"
        case .home:
            return "\u{1b}[H"
        case .end:
            return "\u{1b}[F"
        case .pageUp:
            return "\u{1b}[5~"
        case .pageDown:
            return "\u{1b}[6~"
        case .delete:
            return "\u{7f}" // DEL
        case .deleteForward:
            return "\u{1b}[3~"
        default:
            return nil
        }
    }

    private func handleControlKey(_ characters: String) -> String? {
        // Handle Ctrl+A through Ctrl+Z
        if let firstChar = characters.first, firstChar.isASCII {
            let ascii = firstChar.asciiValue ?? 0
            if ascii >= 97 && ascii <= 122 { // a-z
                let controlCode = ascii - 96 // Ctrl+A = 1, Ctrl+B = 2, etc.
                return String(UnicodeScalar(controlCode))
            }
        }
        return characters
    }

    // MARK: - Mouse Input

    override func mouseDown(with event: NSEvent) {
        // Make sure view becomes first responder
        window?.makeFirstResponder(self)
    }

    // MARK: - Copy/Paste

    @IBAction func copy(_ sender: Any?) {
        // TODO: Implement text selection and copy
        print("Copy not yet implemented")
    }

    @IBAction func paste(_ sender: Any?) {
        guard let terminal = terminal else { return }

        let pasteboard = NSPasteboard.general
        if let string = pasteboard.string(forType: .string) {
            _ = terminal.sendInput(string)
        }
    }

    deinit {
        cursorTimer?.invalidate()
    }
}
