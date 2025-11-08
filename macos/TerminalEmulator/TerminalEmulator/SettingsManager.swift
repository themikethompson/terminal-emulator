import Foundation
import AppKit

/// Centralized settings management
class SettingsManager {
    // MARK: - Singleton

    static let shared = SettingsManager()

    private init() {
        loadSettings()
    }

    // MARK: - Settings Structure

    struct AppearanceSettings: Codable {
        var theme: String = "Default"
        var font: FontSettings = FontSettings()
        var cursorStyle: String = "block"
        var cursorBlinkEnabled: Bool = true
        var cursorBlinkRate: Double = 0.5

        struct FontSettings: Codable {
            var family: String = "Menlo"
            var size: Double = 14
            var ligatures: Bool = true
        }
    }

    struct BehaviorSettings: Codable {
        var scrollback: Int = 10000
        var bellStyle: String = "visual"  // "none", "visual", "audible"
        var closeWindowOnExit: Bool = true
        var confirmBeforeClosing: Bool = true
    }

    struct KeyboardSettings: Codable {
        var optionAsAlt: Bool = true
        var customKeybindings: [String: String] = [:]
    }

    struct AdvancedSettings: Codable {
        var gpuAcceleration: Bool = true
        var metalRenderer: Bool = true
        var fpsLimit: Int = 60
    }

    struct AISettings: Codable {
        var enabled: Bool = false
        var provider: String = "openai"  // "openai", "anthropic", "local"
        var apiKey: String = ""
        var model: String = "gpt-4"
    }

    // MARK: - Settings Storage

    var appearance = AppearanceSettings()
    var behavior = BehaviorSettings()
    var keyboard = KeyboardSettings()
    var advanced = AdvancedSettings()
    var ai = AISettings()

    private let defaults = UserDefaults.standard

    // MARK: - Load/Save

    func loadSettings() {
        if let data = defaults.data(forKey: "appearance"),
           let loaded = try? JSONDecoder().decode(AppearanceSettings.self, from: data) {
            appearance = loaded
        }

        if let data = defaults.data(forKey: "behavior"),
           let loaded = try? JSONDecoder().decode(BehaviorSettings.self, from: data) {
            behavior = loaded
        }

        if let data = defaults.data(forKey: "keyboard"),
           let loaded = try? JSONDecoder().decode(KeyboardSettings.self, from: data) {
            keyboard = loaded
        }

        if let data = defaults.data(forKey: "advanced"),
           let loaded = try? JSONDecoder().decode(AdvancedSettings.self, from: data) {
            advanced = loaded
        }

        if let data = defaults.data(forKey: "ai"),
           let loaded = try? JSONDecoder().decode(AISettings.self, from: data) {
            ai = loaded
        }
    }

    func saveSettings() {
        if let data = try? JSONEncoder().encode(appearance) {
            defaults.set(data, forKey: "appearance")
        }

        if let data = try? JSONEncoder().encode(behavior) {
            defaults.set(data, forKey: "behavior")
        }

        if let data = try? JSONEncoder().encode(keyboard) {
            defaults.set(data, forKey: "keyboard")
        }

        if let data = try? JSONEncoder().encode(advanced) {
            defaults.set(data, forKey: "advanced")
        }

        if let data = try? JSONEncoder().encode(ai) {
            defaults.set(data, forKey: "ai")
        }

        // Post notification
        NotificationCenter.default.post(name: .settingsChanged, object: nil)
    }

    // MARK: - Convenience Methods

    func setFont(family: String, size: Double) {
        appearance.font.family = family
        appearance.font.size = size
        saveSettings()
    }

    func setTheme(_ themeName: String) {
        appearance.theme = themeName
        saveSettings()
    }

    func setCursorStyle(_ style: String) {
        appearance.cursorStyle = style
        saveSettings()
    }

    // MARK: - Export/Import

    func exportSettings(to url: URL) throws {
        let settings: [String: Any] = [
            "appearance": try JSONEncoder().encode(appearance),
            "behavior": try JSONEncoder().encode(behavior),
            "keyboard": try JSONEncoder().encode(keyboard),
            "advanced": try JSONEncoder().encode(advanced),
            "ai": try JSONEncoder().encode(ai)
        ]

        let data = try JSONSerialization.data(withJSONObject: settings, options: .prettyPrinted)
        try data.write(to: url)
    }

    func importSettings(from url: URL) throws {
        let data = try Data(contentsOf: url)
        let settings = try JSONSerialization.jsonObject(with: data) as? [String: Data]

        if let appearanceData = settings?["appearance"] {
            appearance = try JSONDecoder().decode(AppearanceSettings.self, from: appearanceData)
        }

        // ... import other settings

        saveSettings()
    }
}

// MARK: - Notification

extension Notification.Name {
    static let settingsChanged = Notification.Name("settingsChanged")
}

// MARK: - Settings Window Controller

class SettingsWindowController: NSWindowController {
    convenience init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 600, height: 500),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )

        window.title = "Settings"
        window.center()

        self.init(window: window)

        setupToolbar()
    }

    private func setupToolbar() {
        guard let window = window else { return }

        let toolbar = NSToolbar(identifier: "SettingsToolbar")
        toolbar.delegate = self
        toolbar.displayMode = .iconAndLabel

        window.toolbar = toolbar
    }
}

extension SettingsWindowController: NSToolbarDelegate {
    func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        return [
            .general,
            .appearance,
            .profiles,
            .keyboard,
            .advanced
        ]
    }

    func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        return toolbarDefaultItemIdentifiers(toolbar)
    }

    func toolbar(_ toolbar: NSToolbar, itemForItemIdentifier itemIdentifier: NSToolbarItem.Identifier,
                willBeInsertedIntoToolbar flag: Bool) -> NSToolbarItem? {

        let item = NSToolbarItem(itemIdentifier: itemIdentifier)

        switch itemIdentifier {
        case .general:
            item.label = "General"
            item.image = NSImage(systemSymbolName: "gearshape", accessibilityDescription: "General")

        case .appearance:
            item.label = "Appearance"
            item.image = NSImage(systemSymbolName: "paintbrush", accessibilityDescription: "Appearance")

        case .profiles:
            item.label = "Profiles"
            item.image = NSImage(systemSymbolName: "person.crop.circle", accessibilityDescription: "Profiles")

        case .keyboard:
            item.label = "Keyboard"
            item.image = NSImage(systemSymbolName: "keyboard", accessibilityDescription: "Keyboard")

        case .advanced:
            item.label = "Advanced"
            item.image = NSImage(systemSymbolName: "slider.horizontal.3", accessibilityDescription: "Advanced")

        default:
            return nil
        }

        return item
    }
}

extension NSToolbarItem.Identifier {
    static let general = NSToolbarItem.Identifier("general")
    static let appearance = NSToolbarItem.Identifier("appearance")
    static let profiles = NSToolbarItem.Identifier("profiles")
    static let keyboard = NSToolbarItem.Identifier("keyboard")
    static let advanced = NSToolbarItem.Identifier("advanced")
}
