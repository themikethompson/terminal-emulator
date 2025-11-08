import Cocoa
import MetalKit

class TerminalView: MTKView {

    var terminal: TerminalCore?

    // Metal renderer
    private var metalRenderer: MetalRenderer?

    // Font and cell dimensions
    private var font: NSFont
    private var cellWidth: CGFloat = 0
    private var cellHeight: CGFloat = 0

    // Cursor
    private var cursorTimer: Timer?
    private var cursorVisible = true

    // Performance monitoring
    private var lastFrameTime: CFTimeInterval = 0
    private var frameCount: Int = 0
    private var fps: Double = 0

    override init(frame frameRect: NSRect, device: MTLDevice?) {
        // Use a monospace font
        self.font = NSFont.monospacedSystemFont(ofSize: 14, weight: .regular)

        super.init(frame: frameRect, device: device ?? MTLCreateSystemDefaultDevice())

        setupMetal()
        calculateCellDimensions()
        setupCursorTimer()
    }

    required init(coder: NSCoder) {
        self.font = NSFont.monospacedSystemFont(ofSize: 14, weight: .regular)
        super.init(coder: coder)
        setupMetal()
        calculateCellDimensions()
        setupCursorTimer()
    }

    override var acceptsFirstResponder: Bool {
        return true
    }

    private func setupMetal() {
        // Configure Metal view
        self.colorPixelFormat = .bgra8Unorm
        self.clearColor = MTLClearColor(red: 0.0, green: 0.0, blue: 0.0, alpha: 1.0)
        self.framebufferOnly = false
        self.autoResizeDrawable = true
        self.preferredFramesPerSecond = 60
        self.enableSetNeedsDisplay = false
        self.isPaused = false

        // Create Metal renderer
        if let metalRenderer = MetalRenderer(font: font) {
            self.metalRenderer = metalRenderer
            print("Metal renderer initialized successfully")
        } else {
            print("Failed to initialize Metal renderer - falling back would go here")
        }

        // Set self as delegate for draw callbacks
        self.delegate = self
    }

    private func calculateCellDimensions() {
        if let renderer = metalRenderer {
            let size = renderer.getCellSize()
            cellWidth = size.width
            cellHeight = size.height
        } else {
            // Fallback calculation
            let attributes: [NSAttributedString.Key: Any] = [.font: font]
            let charSize = ("M" as NSString).size(withAttributes: attributes)
            cellWidth = ceil(charSize.width)
            cellHeight = ceil(charSize.height)
        }
    }

    private func setupCursorTimer() {
        cursorTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.cursorVisible.toggle()
            // Metal view will automatically redraw at preferred FPS
        }
    }

    func calculateGridSize(for viewSize: NSSize) -> (rows: UInt16, cols: UInt16) {
        let cols = max(1, UInt16(viewSize.width / cellWidth))
        let rows = max(1, UInt16(viewSize.height / cellHeight))
        return (rows, cols)
    }

    deinit {
        cursorTimer?.invalidate()
    }
}

// MARK: - MTKViewDelegate
extension TerminalView: MTKViewDelegate {
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        // Update terminal size when view resizes
        if let terminal = terminal {
            let gridSize = calculateGridSize(for: size)
            terminal.resize(rows: gridSize.rows, cols: gridSize.cols)
        }

        // Update renderer
        if let terminal = terminal {
            metalRenderer?.resize(rows: Int(terminal.rows), cols: Int(terminal.cols))
        }
    }

    func draw(in view: MTKView) {
        guard let terminal = terminal,
              let metalRenderer = metalRenderer,
              let drawable = currentDrawable else {
            return
        }

        // Calculate FPS
        let currentTime = CACurrentMediaTime()
        if lastFrameTime > 0 {
            let delta = currentTime - lastFrameTime
            frameCount += 1
            if frameCount >= 60 {
                fps = Double(frameCount) / (currentTime - lastFrameTime + delta * Double(frameCount - 1))
                // Uncomment to print FPS: print("FPS: \(String(format: "%.1f", fps))")
                frameCount = 0
            }
        }
        lastFrameTime = currentTime

        // Render using Metal
        metalRenderer.render(terminal: terminal,
                           to: drawable,
                           viewportSize: drawableSize)

        // Mark terminal as clean after rendering
        terminal.markClean()
    }
}

// MARK: - TerminalView Input Handling
extension TerminalView {
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
