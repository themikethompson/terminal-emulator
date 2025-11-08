import Foundation

/// Swift wrapper around the Rust terminal core library
class TerminalCore {
    private var terminalPtr: OpaquePointer?

    let rows: UInt16
    let cols: UInt16

    /// Initialize terminal with PTY
    init?(rows: UInt16, cols: UInt16) {
        self.rows = rows
        self.cols = cols

        terminalPtr = terminal_new_with_pty(rows, cols)
        guard terminalPtr != nil else {
            return nil
        }
    }

    /// Initialize terminal without PTY (for testing)
    init(rows: UInt16, cols: UInt16, withPTY: Bool = true) {
        self.rows = rows
        self.cols = cols

        if withPTY {
            terminalPtr = terminal_new_with_pty(rows, cols)
        } else {
            terminalPtr = terminal_new(rows, cols)
        }
    }

    deinit {
        if let ptr = terminalPtr {
            terminal_free(ptr)
        }
    }

    /// Send input to the terminal
    func sendInput(_ data: Data) -> Bool {
        guard let ptr = terminalPtr else { return false }

        let result = data.withUnsafeBytes { bytes in
            terminal_send_input(ptr, bytes.baseAddress?.assumingMemoryBound(to: UInt8.self), data.count)
        }

        return result == 0
    }

    /// Send string input
    func sendInput(_ string: String) -> Bool {
        guard let data = string.data(using: .utf8) else { return false }
        return sendInput(data)
    }

    /// Read from PTY
    func readPTY(into buffer: UnsafeMutablePointer<UInt8>, length: Int) -> Int {
        guard let ptr = terminalPtr else { return -1 }
        return terminal_read_pty(ptr, buffer, length)
    }

    /// Process bytes (parse ANSI and update grid)
    func processBytes(_ data: Data) {
        guard let ptr = terminalPtr else { return }

        data.withUnsafeBytes { bytes in
            terminal_process_bytes(ptr, bytes.baseAddress?.assumingMemoryBound(to: UInt8.self), data.count)
        }
    }

    /// Get cell at position
    func getCell(row: UInt16, col: UInt16) -> CCell {
        guard let ptr = terminalPtr else {
            return CCell(ch: 32, fg_r: 200, fg_g: 200, fg_b: 200,
                        bg_r: 0, bg_g: 0, bg_b: 0, flags: 0)
        }
        return terminal_get_cell(ptr, row, col)
    }

    /// Get entire row (more efficient for rendering)
    func getRow(_ row: UInt16) -> [CCell] {
        guard let ptr = terminalPtr else { return [] }

        var buffer = [CCell](repeating: CCell(ch: 32, fg_r: 200, fg_g: 200, fg_b: 200,
                                               bg_r: 0, bg_g: 0, bg_b: 0, flags: 0),
                            count: Int(cols))

        let count = buffer.withUnsafeMutableBufferPointer { buf in
            terminal_get_row(ptr, row, buf.baseAddress, buf.count)
        }

        return Array(buffer.prefix(count))
    }

    /// Get cursor position
    var cursorPosition: (row: UInt16, col: UInt16) {
        guard let ptr = terminalPtr else { return (0, 0) }
        return (terminal_get_cursor_row(ptr), terminal_get_cursor_col(ptr))
    }

    /// Resize terminal
    func resize(rows: UInt16, cols: UInt16) {
        guard let ptr = terminalPtr else { return }
        terminal_resize(ptr, rows, cols)
    }

    /// Get dirty rows (rows that changed since last mark_clean)
    func getDirtyRows() -> [UInt16] {
        guard let ptr = terminalPtr else { return [] }

        var buffer = [UInt16](repeating: 0, count: Int(rows))
        let count = buffer.withUnsafeMutableBufferPointer { buf in
            terminal_get_dirty_rows(ptr, buf.baseAddress, buf.count)
        }

        return Array(buffer.prefix(count))
    }

    /// Mark all rows as clean (call after rendering)
    func markClean() {
        guard let ptr = terminalPtr else { return }
        terminal_mark_clean(ptr)
    }

    /// Get PTY file descriptor for monitoring
    var ptyFileDescriptor: Int32 {
        guard let ptr = terminalPtr else { return -1 }
        return terminal_get_pty_fd(ptr)
    }
}
