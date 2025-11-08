import Foundation

/// Manages plugins for the terminal emulator
/// Note: Full WASM support would require integrating WasmKit or similar
/// This provides the plugin infrastructure
class PluginManager {
    // MARK: - Types

    struct Plugin {
        let id: UUID
        let name: String
        let version: String
        let author: String
        let description: String
        let enabled: Bool
        let manifestURL: URL
        let hooks: [PluginHook]
    }

    enum PluginHook {
        case preCommand         // Before command execution
        case postCommand        // After command execution
        case outputFilter       // Filter/modify output
        case inputFilter        // Filter/modify input
        case customCommand      // Add custom commands
        case uiExtension        // Add UI elements
        case themeProvider      // Provide themes
        case completionProvider // Provide completions
    }

    struct PluginManifest: Codable {
        let name: String
        let version: String
        let author: String
        let description: String
        let main: String  // Entry point (WASM file)
        let hooks: [String]
        let permissions: [String]
    }

    // MARK: - Properties

    private var plugins: [UUID: Plugin] = [:]
    private let pluginsDirectory: URL

    // Hook handlers
    private var preCommandHandlers: [(String) -> String] = []
    private var postCommandHandlers: [(String, String) -> Void] = []
    private var outputFilterHandlers: [(String) -> String] = []

    // MARK: - Initialization

    init() {
        // Create plugins directory
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let appDirectory = appSupport.appendingPathComponent("TerminalEmulator", isDirectory: true)

        pluginsDirectory = appDirectory.appendingPathComponent("Plugins", isDirectory: true)

        try? FileManager.default.createDirectory(at: pluginsDirectory, withIntermediateDirectories: true)

        // Load plugins
        loadPlugins()
    }

    // MARK: - Plugin Loading

    /// Load all plugins from plugins directory
    func loadPlugins() {
        guard let contents = try? FileManager.default.contentsOfDirectory(
            at: pluginsDirectory,
            includingPropertiesForKeys: nil
        ) else { return }

        for pluginDir in contents where pluginDir.hasDirectoryPath {
            loadPlugin(from: pluginDir)
        }
    }

    /// Load a specific plugin
    private func loadPlugin(from directory: URL) {
        let manifestURL = directory.appendingPathComponent("manifest.json")

        guard let data = try? Data(contentsOf: manifestURL),
              let manifest = try? JSONDecoder().decode(PluginManifest.self, from: data) else {
            print("Failed to load plugin manifest from \(directory.lastPathComponent)")
            return
        }

        let plugin = Plugin(
            id: UUID(),
            name: manifest.name,
            version: manifest.version,
            author: manifest.author,
            description: manifest.description,
            enabled: true,
            manifestURL: manifestURL,
            hooks: parseHooks(manifest.hooks)
        )

        plugins[plugin.id] = plugin

        // Register hooks
        registerPluginHooks(plugin)

        print("Loaded plugin: \(plugin.name) v\(plugin.version)")
    }

    private func parseHooks(_ hookStrings: [String]) -> [PluginHook] {
        return hookStrings.compactMap { hookString in
            switch hookString {
            case "preCommand": return .preCommand
            case "postCommand": return .postCommand
            case "outputFilter": return .outputFilter
            case "inputFilter": return .inputFilter
            case "customCommand": return .customCommand
            case "uiExtension": return .uiExtension
            case "themeProvider": return .themeProvider
            case "completionProvider": return .completionProvider
            default: return nil
            }
        }
    }

    // MARK: - Hook Registration

    private func registerPluginHooks(_ plugin: Plugin) {
        for hook in plugin.hooks {
            switch hook {
            case .preCommand:
                registerPreCommandHook(for: plugin)
            case .postCommand:
                registerPostCommandHook(for: plugin)
            case .outputFilter:
                registerOutputFilterHook(for: plugin)
            default:
                break
            }
        }
    }

    private func registerPreCommandHook(for plugin: Plugin) {
        // In a real implementation, this would call the WASM module
        preCommandHandlers.append { command in
            // Placeholder: Call plugin's preCommand function
            return command
        }
    }

    private func registerPostCommandHook(for plugin: Plugin) {
        postCommandHandlers.append { command, output in
            // Placeholder: Call plugin's postCommand function
        }
    }

    private func registerOutputFilterHook(for plugin: Plugin) {
        outputFilterHandlers.append { output in
            // Placeholder: Call plugin's outputFilter function
            return output
        }
    }

    // MARK: - Hook Execution

    /// Execute pre-command hooks
    func executePreCommandHooks(_ command: String) -> String {
        var modifiedCommand = command

        for handler in preCommandHandlers {
            modifiedCommand = handler(modifiedCommand)
        }

        return modifiedCommand
    }

    /// Execute post-command hooks
    func executePostCommandHooks(command: String, output: String) {
        for handler in postCommandHandlers {
            handler(command, output)
        }
    }

    /// Execute output filter hooks
    func executeOutputFilterHooks(_ output: String) -> String {
        var modifiedOutput = output

        for handler in outputFilterHandlers {
            modifiedOutput = handler(modifiedOutput)
        }

        return modifiedOutput
    }

    // MARK: - Plugin Management

    /// Get all plugins
    func getAllPlugins() -> [Plugin] {
        return Array(plugins.values)
    }

    /// Get enabled plugins
    func getEnabledPlugins() -> [Plugin] {
        return plugins.values.filter { $0.enabled }
    }

    /// Enable/disable plugin
    func setPluginEnabled(_ pluginId: UUID, enabled: Bool) {
        // Would need to make Plugin properties mutable
        // Simplified for now
    }

    /// Install plugin from URL
    func installPlugin(from url: URL) throws {
        // Download and extract plugin
        // Validate manifest
        // Copy to plugins directory
        // Load plugin
    }

    /// Uninstall plugin
    func uninstallPlugin(_ pluginId: UUID) throws {
        guard let plugin = plugins[pluginId] else { return }

        // Remove from plugins directory
        let pluginDir = plugin.manifestURL.deletingLastPathComponent()
        try FileManager.default.removeItem(at: pluginDir)

        // Remove from loaded plugins
        plugins.removeValue(forKey: pluginId)
    }
}

// MARK: - Plugin API (for plugin developers)

/// Base protocol for plugin functionality
protocol PluginAPI {
    /// Get terminal output
    func getOutput() -> String

    /// Send input to terminal
    func sendInput(_ input: String)

    /// Get current working directory
    func getWorkingDirectory() -> String

    /// Show notification
    func showNotification(title: String, message: String)

    /// Register custom command
    func registerCommand(name: String, handler: @escaping (String) -> String)
}

/// Example plugin implementation (Swift-based, not WASM)
class ExamplePlugin {
    let name = "Example Plugin"
    let version = "1.0.0"

    func onPreCommand(command: String) -> String {
        // Modify command before execution
        print("Plugin intercepted command: \(command)")
        return command
    }

    func onPostCommand(command: String, output: String) {
        // React to command execution
        print("Command executed: \(command)")
    }

    func onOutputFilter(output: String) -> String {
        // Filter/modify output
        return output
    }
}

// MARK: - Plugin Sandbox

/// Sandboxing for plugins to prevent malicious behavior
class PluginSandbox {
    // File system access restrictions
    var allowedReadPaths: Set<String> = []
    var allowedWritePaths: Set<String> = []

    // Network access
    var allowNetworkAccess: Bool = false
    var allowedHosts: Set<String> = []

    // System access
    var allowProcessExecution: Bool = false
    var allowShellAccess: Bool = false

    func checkFileAccess(path: String, mode: AccessMode) -> Bool {
        switch mode {
        case .read:
            return allowedReadPaths.contains(path)
        case .write:
            return allowedWritePaths.contains(path)
        }
    }

    enum AccessMode {
        case read, write
    }
}
