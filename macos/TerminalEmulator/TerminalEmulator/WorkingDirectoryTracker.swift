import Foundation

/// Tracks the current working directory of the terminal shell
class WorkingDirectoryTracker {
    // MARK: - Properties

    private(set) var currentDirectory: String = "~"
    private var pid: pid_t?

    // MARK: - Tracking

    /// Start tracking working directory for a process
    func startTracking(pid: pid_t) {
        self.pid = pid
        updateWorkingDirectory()
    }

    /// Update current working directory
    func updateWorkingDirectory() {
        guard let pid = pid else { return }

        // Use lsof to get the working directory
        if let cwd = getWorkingDirectory(for: pid) {
            currentDirectory = cwd
        }
    }

    private func getWorkingDirectory(for pid: pid_t) -> String? {
        // Use /proc filesystem (if available) or lsof
        #if os(macOS)
        return getWorkingDirectoryMacOS(for: pid)
        #else
        return getWorkingDirectoryLinux(for: pid)
        #endif
    }

    private func getWorkingDirectoryMacOS(for pid: pid_t) -> String? {
        // On macOS, use lsof to get current working directory
        let task = Process()
        task.launchPath = "/usr/sbin/lsof"
        task.arguments = ["-a", "-p", "\(pid)", "-d", "cwd", "-Fn"]

        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = Pipe()

        do {
            try task.run()
            task.waitUntilExit()

            let data = pipe.fileHandleForReading.readDataToEndOfFile()

            if let output = String(data: data, encoding: .utf8) {
                // Parse lsof output
                // Format: "n/path/to/directory"
                for line in output.components(separatedBy: "\n") {
                    if line.hasPrefix("n/") {
                        let path = String(line.dropFirst(1))  // Remove 'n' prefix
                        return path
                    }
                }
            }
        } catch {
            print("Failed to get working directory: \(error)")
        }

        return nil
    }

    private func getWorkingDirectoryLinux(for pid: pid_t) -> String? {
        // On Linux, read /proc/<pid>/cwd symlink
        let path = "/proc/\(pid)/cwd"

        do {
            let cwd = try FileManager.default.destinationOfSymbolicLink(atPath: path)
            return cwd
        } catch {
            return nil
        }
    }

    // MARK: - OSC 7 Support (Modern approach)

    /// Parse OSC 7 escape sequence for working directory
    /// Format: ESC ] 7 ; file://hostname/path BEL
    func parseOSC7(_ sequence: String) {
        if sequence.hasPrefix("file://") {
            let urlString = String(sequence.dropFirst(7))  // Remove "file://"

            // Extract path from URL
            if let url = URL(string: "file://\(urlString)"),
               let path = url.path.removingPercentEncoding {
                currentDirectory = path
            }
        }
    }

    // MARK: - Directory History

    private var directoryHistory: [String] = []
    private let maxHistorySize = 50

    /// Add directory to history
    func addToHistory(_ directory: String) {
        // Remove if already exists
        directoryHistory.removeAll { $0 == directory }

        // Add to front
        directoryHistory.insert(directory, at: 0)

        // Trim to max size
        if directoryHistory.count > maxHistorySize {
            directoryHistory = Array(directoryHistory.prefix(maxHistorySize))
        }
    }

    /// Get directory history
    func getHistory() -> [String] {
        return directoryHistory
    }

    /// Get recent directories (excluding current)
    func getRecentDirectories(limit: Int = 10) -> [String] {
        return directoryHistory.filter { $0 != currentDirectory }.prefix(limit).map { $0 }
    }
}

// MARK: - Directory Monitoring

extension WorkingDirectoryTracker {
    /// Start periodic polling of working directory
    func startPeriodicUpdate(interval: TimeInterval = 1.0) {
        Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            self?.updateWorkingDirectory()
        }
    }
}
