import Cocoa

class TerminalViewController: NSViewController {

    private var terminalView: TerminalView!
    private var terminal: TerminalCore?
    private var ptySource: DispatchSourceRead?

    override func loadView() {
        // Create terminal view
        terminalView = TerminalView(frame: NSRect(x: 0, y: 0, width: 800, height: 600))
        self.view = terminalView
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        // Initialize terminal core (24 rows x 80 cols)
        terminal = TerminalCore(rows: 24, cols: 80)

        guard let terminal = terminal else {
            print("Failed to create terminal")
            return
        }

        // Connect terminal to view
        terminalView.terminal = terminal

        // Set up PTY monitoring
        setupPTYMonitoring()

        // Initial render
        terminalView.needsDisplay = true
    }

    private func setupPTYMonitoring() {
        guard let terminal = terminal else { return }

        let fd = terminal.ptyFileDescriptor
        guard fd >= 0 else {
            print("Invalid PTY file descriptor")
            return
        }

        // Create dispatch source to monitor PTY for output
        ptySource = DispatchSource.makeReadSource(fileDescriptor: fd, queue: .main)

        ptySource?.setEventHandler { [weak self] in
            self?.handlePTYOutput()
        }

        ptySource?.setCancelHandler {
            close(fd)
        }

        ptySource?.resume()
    }

    private func handlePTYOutput() {
        guard let terminal = terminal else { return }

        // Read from PTY
        var buffer = [UInt8](repeating: 0, count: 4096)
        let bytesRead = buffer.withUnsafeMutableBufferPointer { buf in
            terminal.readPTY(into: buf.baseAddress!, length: buf.count)
        }

        if bytesRead > 0 {
            // Process the output through the parser
            let data = Data(bytes: buffer, count: bytesRead)
            terminal.processBytes(data)

            // Trigger redraw
            DispatchQueue.main.async { [weak self] in
                self?.terminalView.needsDisplay = true
            }
        } else if bytesRead < 0 {
            // Error or EOF
            print("PTY read error or EOF")
            ptySource?.cancel()
        }
    }

    override func viewDidLayout() {
        super.viewDidLayout()

        // Handle terminal resize when view size changes
        guard let terminal = terminal else { return }

        let viewSize = view.bounds.size
        let (rows, cols) = terminalView.calculateGridSize(for: viewSize)

        if rows != terminal.rows || cols != terminal.cols {
            terminal.resize(rows: rows, cols: cols)
            terminalView.needsDisplay = true
        }
    }

    deinit {
        ptySource?.cancel()
    }
}
