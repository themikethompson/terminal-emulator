import Foundation

/// Manages terminal session persistence
class SessionManager {
    // MARK: - Types

    struct TerminalSession: Codable {
        let id: UUID
        let title: String
        let workingDirectory: String
        let rows: UInt16
        let cols: UInt16
        let scrollbackLines: Int
        let cursorPosition: CursorPosition
        let createdAt: Date
        let lastModified: Date

        // Grid state (optional - can be large)
        let gridState: GridState?

        struct CursorPosition: Codable {
            let row: UInt16
            let col: UInt16
        }

        struct GridState: Codable {
            let rows: [[CellState]]

            struct CellState: Codable {
                let ch: UInt32
                let fg_r: UInt8
                let fg_g: UInt8
                let fg_b: UInt8
                let bg_r: UInt8
                let bg_g: UInt8
                let bg_b: UInt8
                let flags: UInt32
            }
        }
    }

    struct WindowSession: Codable {
        let id: UUID
        let tabs: [TabSession]
        let selectedTabIndex: Int
        let windowFrame: WindowFrame

        struct WindowFrame: Codable {
            let x: Double
            let y: Double
            let width: Double
            let height: Double
        }
    }

    struct TabSession: Codable {
        let id: UUID
        let title: String
        let terminals: [TerminalSession]
        let splitConfiguration: SplitConfiguration?

        struct SplitConfiguration: Codable {
            let direction: String  // "horizontal" or "vertical"
            let ratio: Double
        }
    }

    // MARK: - Properties

    private let fileManager = FileManager.default
    private let sessionsDirectory: URL

    var autoSaveEnabled: Bool = true
    var autoSaveInterval: TimeInterval = 60.0  // 60 seconds

    private var autoSaveTimer: Timer?

    // MARK: - Initialization

    init() {
        // Create sessions directory in Application Support
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let appDirectory = appSupport.appendingPathComponent("TerminalEmulator", isDirectory: true)

        sessionsDirectory = appDirectory.appendingPathComponent("Sessions", isDirectory: true)

        // Create directory if needed
        try? fileManager.createDirectory(at: sessionsDirectory, withIntermediateDirectories: true)
    }

    // MARK: - Session Saving

    /// Save a terminal session
    func saveSession(_ session: TerminalSession, name: String? = nil) throws {
        let fileName = name ?? "\(session.id.uuidString).json"
        let fileURL = sessionsDirectory.appendingPathComponent(fileName)

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        let data = try encoder.encode(session)
        try data.write(to: fileURL)
    }

    /// Save window session (multiple tabs)
    func saveWindowSession(_ session: WindowSession, name: String? = nil) throws {
        let fileName = name ?? "window_\(session.id.uuidString).json"
        let fileURL = sessionsDirectory.appendingPathComponent(fileName)

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        let data = try encoder.encode(session)
        try data.write(to: fileURL)
    }

    /// Save current session (called by auto-save)
    func saveCurrentSession(window: WindowSession) throws {
        try saveWindowSession(window, name: "current_session.json")
    }

    // MARK: - Session Loading

    /// Load a terminal session
    func loadSession(name: String) throws -> TerminalSession {
        let fileURL = sessionsDirectory.appendingPathComponent(name)

        let data = try Data(contentsOf: fileURL)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        return try decoder.decode(TerminalSession.self, from: data)
    }

    /// Load window session
    func loadWindowSession(name: String) throws -> WindowSession {
        let fileURL = sessionsDirectory.appendingPathComponent(name)

        let data = try Data(contentsOf: fileURL)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        return try decoder.decode(WindowSession.self, from: data)
    }

    /// Load last session (on app startup)
    func loadLastSession() throws -> WindowSession? {
        let fileURL = sessionsDirectory.appendingPathComponent("current_session.json")

        guard fileManager.fileExists(atPath: fileURL.path) else {
            return nil
        }

        return try loadWindowSession(name: "current_session.json")
    }

    // MARK: - Session Listing

    /// Get all saved sessions
    func listSessions() throws -> [String] {
        let contents = try fileManager.contentsOfDirectory(at: sessionsDirectory,
                                                           includingPropertiesForKeys: [.creationDateKey],
                                                           options: .skipsHiddenFiles)

        return contents
            .filter { $0.pathExtension == "json" }
            .map { $0.lastPathComponent }
            .sorted()
    }

    /// Get session metadata
    func getSessionMetadata(name: String) throws -> (created: Date, modified: Date, size: Int64) {
        let fileURL = sessionsDirectory.appendingPathComponent(name)

        let attributes = try fileManager.attributesOfItem(atPath: fileURL.path)

        let created = attributes[.creationDate] as? Date ?? Date()
        let modified = attributes[.modificationDate] as? Date ?? Date()
        let size = attributes[.size] as? Int64 ?? 0

        return (created, modified, size)
    }

    // MARK: - Session Deletion

    /// Delete a session
    func deleteSession(name: String) throws {
        let fileURL = sessionsDirectory.appendingPathComponent(name)
        try fileManager.removeItem(at: fileURL)
    }

    /// Delete all sessions
    func deleteAllSessions() throws {
        let contents = try fileManager.contentsOfDirectory(at: sessionsDirectory,
                                                           includingPropertiesForKeys: nil)

        for fileURL in contents {
            try fileManager.removeItem(at: fileURL)
        }
    }

    // MARK: - Auto-save

    /// Start auto-save timer
    func startAutoSave(saveHandler: @escaping () -> Void) {
        guard autoSaveEnabled else { return }

        autoSaveTimer?.invalidate()

        autoSaveTimer = Timer.scheduledTimer(withTimeInterval: autoSaveInterval, repeats: true) { _ in
            saveHandler()
        }
    }

    /// Stop auto-save timer
    func stopAutoSave() {
        autoSaveTimer?.invalidate()
        autoSaveTimer = nil
    }

    // MARK: - Session Capture

    /// Capture current terminal state
    func captureTerminalSession(from terminal: TerminalCore, title: String, workingDir: String) -> TerminalSession {
        let cursorPos = terminal.cursorPosition

        // Optionally capture grid state (can be large)
        let gridState = captureGridState(from: terminal)

        return TerminalSession(
            id: UUID(),
            title: title,
            workingDirectory: workingDir,
            rows: terminal.rows,
            cols: terminal.cols,
            scrollbackLines: 10000,  // TODO: Get from terminal
            cursorPosition: TerminalSession.CursorPosition(row: cursorPos.row, col: cursorPos.col),
            createdAt: Date(),
            lastModified: Date(),
            gridState: gridState
        )
    }

    private func captureGridState(from terminal: TerminalCore) -> TerminalSession.GridState? {
        var rows: [[TerminalSession.GridState.CellState]] = []

        for row in 0..<Int(terminal.rows) {
            guard let rowData = terminal.getRow(row) else { continue }

            let cellStates = rowData.map { cell in
                TerminalSession.GridState.CellState(
                    ch: cell.ch,
                    fg_r: cell.fg_r,
                    fg_g: cell.fg_g,
                    fg_b: cell.fg_b,
                    bg_r: cell.bg_r,
                    bg_g: cell.bg_g,
                    bg_b: cell.bg_b,
                    flags: cell.flags
                )
            }

            rows.append(cellStates)
        }

        return TerminalSession.GridState(rows: rows)
    }

    // MARK: - Session Restore

    /// Restore terminal from session
    func restoreTerminal(from session: TerminalSession) -> TerminalCore? {
        // Create terminal with saved dimensions
        let terminal = TerminalCore(rows: session.rows, cols: session.cols)

        // TODO: Restore grid state if available
        // This would require adding a restore method to the Rust core

        return terminal
    }
}

// MARK: - Session Configuration

struct SessionConfiguration: Codable {
    // Session behavior
    var restoreSessionsOnStartup: Bool = true
    var saveGridState: Bool = false  // Can be large, off by default
    var maxSessionFiles: Int = 50

    // Auto-save
    var autoSaveEnabled: Bool = true
    var autoSaveInterval: TimeInterval = 60.0

    // Session cleanup
    var deleteOldSessions: Bool = true
    var sessionMaxAge: TimeInterval = 30 * 24 * 60 * 60  // 30 days

    static func load() -> SessionConfiguration {
        let defaults = UserDefaults.standard

        return SessionConfiguration(
            restoreSessionsOnStartup: defaults.bool(forKey: "restoreSessionsOnStartup"),
            saveGridState: defaults.bool(forKey: "saveGridState"),
            maxSessionFiles: defaults.integer(forKey: "maxSessionFiles"),
            autoSaveEnabled: defaults.bool(forKey: "autoSaveEnabled"),
            autoSaveInterval: defaults.double(forKey: "autoSaveInterval"),
            deleteOldSessions: defaults.bool(forKey: "deleteOldSessions"),
            sessionMaxAge: defaults.double(forKey: "sessionMaxAge")
        )
    }

    func save() {
        let defaults = UserDefaults.standard

        defaults.set(restoreSessionsOnStartup, forKey: "restoreSessionsOnStartup")
        defaults.set(saveGridState, forKey: "saveGridState")
        defaults.set(maxSessionFiles, forKey: "maxSessionFiles")
        defaults.set(autoSaveEnabled, forKey: "autoSaveEnabled")
        defaults.set(autoSaveInterval, forKey: "autoSaveInterval")
        defaults.set(deleteOldSessions, forKey: "deleteOldSessions")
        defaults.set(sessionMaxAge, forKey: "sessionMaxAge")
    }
}
