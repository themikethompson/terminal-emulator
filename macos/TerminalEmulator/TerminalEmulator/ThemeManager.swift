import AppKit

/// Manages terminal color themes
class ThemeManager {
    // MARK: - Types

    struct Theme: Codable {
        let name: String
        let author: String
        let colors: ThemeColors
        let metadata: ThemeMetadata?

        struct ThemeColors: Codable {
            // Background and foreground
            let background: ColorRGB
            let foreground: ColorRGB

            // Cursor
            let cursor: ColorRGB
            let cursorText: ColorRGB?

            // Selection
            let selection: ColorRGB

            // ANSI colors (16 colors)
            let black: ColorRGB
            let red: ColorRGB
            let green: ColorRGB
            let yellow: ColorRGB
            let blue: ColorRGB
            let magenta: ColorRGB
            let cyan: ColorRGB
            let white: ColorRGB

            let brightBlack: ColorRGB
            let brightRed: ColorRGB
            let brightGreen: ColorRGB
            let brightYellow: ColorRGB
            let brightBlue: ColorRGB
            let brightMagenta: ColorRGB
            let brightCyan: ColorRGB
            let brightWhite: ColorRGB
        }

        struct ColorRGB: Codable {
            let r: Int
            let g: Int
            let b: Int
            let a: Int?  // Optional alpha

            var nsColor: NSColor {
                NSColor(red: CGFloat(r) / 255.0,
                       green: CGFloat(g) / 255.0,
                       blue: CGFloat(b) / 255.0,
                       alpha: CGFloat(a ?? 255) / 255.0)
            }
        }

        struct ThemeMetadata: Codable {
            let description: String?
            let url: String?
            let version: String?
        }
    }

    // MARK: - Properties

    private(set) var currentTheme: Theme
    private var availableThemes: [String: Theme] = [:]
    private let themesDirectory: URL

    // MARK: - Initialization

    init() {
        // Create themes directory
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let appDirectory = appSupport.appendingPathComponent("TerminalEmulator", isDirectory: true)

        themesDirectory = appDirectory.appendingPathComponent("Themes", isDirectory: true)

        try? FileManager.default.createDirectory(at: themesDirectory, withIntermediateDirectories: true)

        // Load default theme
        self.currentTheme = Self.defaultTheme()

        // Load saved themes
        loadThemes()

        // Load user's preferred theme
        if let savedThemeName = UserDefaults.standard.string(forKey: "selectedTheme"),
           let savedTheme = availableThemes[savedThemeName] {
            currentTheme = savedTheme
        }
    }

    // MARK: - Theme Management

    /// Load all themes from directory
    func loadThemes() {
        // Add built-in themes
        availableThemes["Default"] = Self.defaultTheme()
        availableThemes["Solarized Dark"] = Self.solarizedDark()
        availableThemes["Solarized Light"] = Self.solarizedLight()
        availableThemes["Dracula"] = Self.dracula()
        availableThemes["Monokai"] = Self.monokai()
        availableThemes["One Dark"] = Self.oneDark()
        availableThemes["Nord"] = Self.nord()

        // Load custom themes from directory
        guard let contents = try? FileManager.default.contentsOfDirectory(
            at: themesDirectory,
            includingPropertiesForKeys: nil
        ) else { return }

        for fileURL in contents where fileURL.pathExtension == "json" {
            if let theme = loadTheme(from: fileURL) {
                availableThemes[theme.name] = theme
            }
        }
    }

    /// Load a theme from file
    private func loadTheme(from url: URL) -> Theme? {
        guard let data = try? Data(contentsOf: url),
              let theme = try? JSONDecoder().decode(Theme.self, from: data) else {
            return nil
        }

        return theme
    }

    /// Save a theme
    func saveTheme(_ theme: Theme) throws {
        let fileURL = themesDirectory.appendingPathComponent("\(theme.name).json")

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        let data = try encoder.encode(theme)
        try data.write(to: fileURL)

        availableThemes[theme.name] = theme
    }

    /// Set current theme
    func setTheme(_ themeName: String) {
        guard let theme = availableThemes[themeName] else { return }

        currentTheme = theme

        // Save preference
        UserDefaults.standard.set(themeName, forKey: "selectedTheme")

        // Post notification for UI update
        NotificationCenter.default.post(name: .themeChanged, object: theme)
    }

    /// Get all available themes
    func getAvailableThemes() -> [String] {
        return Array(availableThemes.keys).sorted()
    }

    /// Get a specific theme
    func getTheme(named name: String) -> Theme? {
        return availableThemes[name]
    }

    // MARK: - Built-in Themes

    static func defaultTheme() -> Theme {
        Theme(
            name: "Default",
            author: "Terminal Emulator",
            colors: Theme.ThemeColors(
                background: Theme.ColorRGB(r: 0, g: 0, b: 0),
                foreground: Theme.ColorRGB(r: 255, g: 255, b: 255),
                cursor: Theme.ColorRGB(r: 255, g: 255, b: 255),
                cursorText: nil,
                selection: Theme.ColorRGB(r: 100, g: 100, b: 100),
                black: Theme.ColorRGB(r: 0, g: 0, b: 0),
                red: Theme.ColorRGB(r: 205, g: 49, b: 49),
                green: Theme.ColorRGB(r: 13, g: 188, b: 121),
                yellow: Theme.ColorRGB(r: 229, g: 229, b: 16),
                blue: Theme.ColorRGB(r: 36, g: 114, b: 200),
                magenta: Theme.ColorRGB(r: 188, g: 63, b: 188),
                cyan: Theme.ColorRGB(r: 17, g: 168, b: 205),
                white: Theme.ColorRGB(r: 229, g: 229, b: 229),
                brightBlack: Theme.ColorRGB(r: 102, g: 102, b: 102),
                brightRed: Theme.ColorRGB(r: 241, g: 76, b: 76),
                brightGreen: Theme.ColorRGB(r: 35, g: 209, b: 139),
                brightYellow: Theme.ColorRGB(r: 245, g: 245, b: 67),
                brightBlue: Theme.ColorRGB(r: 59, g: 142, b: 234),
                brightMagenta: Theme.ColorRGB(r: 214, g: 112, b: 214),
                brightCyan: Theme.ColorRGB(r: 41, g: 184, b: 219),
                brightWhite: Theme.ColorRGB(r: 255, g: 255, b: 255)
            ),
            metadata: nil
        )
    }

    static func solarizedDark() -> Theme {
        Theme(
            name: "Solarized Dark",
            author: "Ethan Schoonover",
            colors: Theme.ThemeColors(
                background: Theme.ColorRGB(r: 0, g: 43, b: 54),
                foreground: Theme.ColorRGB(r: 131, g: 148, b: 150),
                cursor: Theme.ColorRGB(r: 147, g: 161, b: 161),
                cursorText: nil,
                selection: Theme.ColorRGB(r: 7, g: 54, b: 66),
                black: Theme.ColorRGB(r: 7, g: 54, b: 66),
                red: Theme.ColorRGB(r: 220, g: 50, b: 47),
                green: Theme.ColorRGB(r: 133, g: 153, b: 0),
                yellow: Theme.ColorRGB(r: 181, g: 137, b: 0),
                blue: Theme.ColorRGB(r: 38, g: 139, b: 210),
                magenta: Theme.ColorRGB(r: 211, g: 54, b: 130),
                cyan: Theme.ColorRGB(r: 42, g: 161, b: 152),
                white: Theme.ColorRGB(r: 238, g: 232, b: 213),
                brightBlack: Theme.ColorRGB(r: 0, g: 43, b: 54),
                brightRed: Theme.ColorRGB(r: 203, g: 75, b: 22),
                brightGreen: Theme.ColorRGB(r: 88, g: 110, b: 117),
                brightYellow: Theme.ColorRGB(r: 101, g: 123, b: 131),
                brightBlue: Theme.ColorRGB(r: 131, g: 148, b: 150),
                brightMagenta: Theme.ColorRGB(r: 108, g: 113, b: 196),
                brightCyan: Theme.ColorRGB(r: 147, g: 161, b: 161),
                brightWhite: Theme.ColorRGB(r: 253, g: 246, b: 227)
            ),
            metadata: Theme.ThemeMetadata(
                description: "Precision colors for machines and people",
                url: "https://ethanschoonover.com/solarized/",
                version: "1.0"
            )
        )
    }

    static func solarizedLight() -> Theme {
        Theme(
            name: "Solarized Light",
            author: "Ethan Schoonover",
            colors: Theme.ThemeColors(
                background: Theme.ColorRGB(r: 253, g: 246, b: 227),
                foreground: Theme.ColorRGB(r: 101, g: 123, b: 131),
                cursor: Theme.ColorRGB(r: 101, g: 123, b: 131),
                cursorText: nil,
                selection: Theme.ColorRGB(r: 238, g: 232, b: 213),
                black: Theme.ColorRGB(r: 7, g: 54, b: 66),
                red: Theme.ColorRGB(r: 220, g: 50, b: 47),
                green: Theme.ColorRGB(r: 133, g: 153, b: 0),
                yellow: Theme.ColorRGB(r: 181, g: 137, b: 0),
                blue: Theme.ColorRGB(r: 38, g: 139, b: 210),
                magenta: Theme.ColorRGB(r: 211, g: 54, b: 130),
                cyan: Theme.ColorRGB(r: 42, g: 161, b: 152),
                white: Theme.ColorRGB(r: 238, g: 232, b: 213),
                brightBlack: Theme.ColorRGB(r: 0, g: 43, b: 54),
                brightRed: Theme.ColorRGB(r: 203, g: 75, b: 22),
                brightGreen: Theme.ColorRGB(r: 88, g: 110, b: 117),
                brightYellow: Theme.ColorRGB(r: 101, g: 123, b: 131),
                brightBlue: Theme.ColorRGB(r: 131, g: 148, b: 150),
                brightMagenta: Theme.ColorRGB(r: 108, g: 113, b: 196),
                brightCyan: Theme.ColorRGB(r: 147, g: 161, b: 161),
                brightWhite: Theme.ColorRGB(r: 253, g: 246, b: 227)
            ),
            metadata: nil
        )
    }

    static func dracula() -> Theme {
        Theme(
            name: "Dracula",
            author: "Zeno Rocha",
            colors: Theme.ThemeColors(
                background: Theme.ColorRGB(r: 40, g: 42, b: 54),
                foreground: Theme.ColorRGB(r: 248, g: 248, b: 242),
                cursor: Theme.ColorRGB(r: 248, g: 248, b: 240),
                cursorText: nil,
                selection: Theme.ColorRGB(r: 68, g: 71, b: 90),
                black: Theme.ColorRGB(r: 0, g: 0, b: 0),
                red: Theme.ColorRGB(r: 255, g: 85, b: 85),
                green: Theme.ColorRGB(r: 80, g: 250, b: 123),
                yellow: Theme.ColorRGB(r: 241, g: 250, b: 140),
                blue: Theme.ColorRGB(r: 189, g: 147, b: 249),
                magenta: Theme.ColorRGB(r: 255, g: 121, b: 198),
                cyan: Theme.ColorRGB(r: 139, g: 233, b: 253),
                white: Theme.ColorRGB(r: 191, g: 191, b: 191),
                brightBlack: Theme.ColorRGB(r: 85, g: 85, b: 85),
                brightRed: Theme.ColorRGB(r: 255, g: 110, b: 103),
                brightGreen: Theme.ColorRGB(r: 90, g: 247, b: 142),
                brightYellow: Theme.ColorRGB(r: 244, g: 249, b: 157),
                brightBlue: Theme.ColorRGB(r: 202, g: 169, b: 250),
                brightMagenta: Theme.ColorRGB(r: 255, g: 146, b: 208),
                brightCyan: Theme.ColorRGB(r: 154, g: 237, b: 254),
                brightWhite: Theme.ColorRGB(r: 230, g: 230, b: 230)
            ),
            metadata: nil
        )
    }

    static func monokai() -> Theme {
        Theme(
            name: "Monokai",
            author: "Wimer Hazenberg",
            colors: Theme.ThemeColors(
                background: Theme.ColorRGB(r: 39, g: 40, b: 34),
                foreground: Theme.ColorRGB(r: 248, g: 248, b: 240),
                cursor: Theme.ColorRGB(r: 253, g: 151, b: 31),
                cursorText: nil,
                selection: Theme.ColorRGB(r: 73, g: 72, b: 62),
                black: Theme.ColorRGB(r: 39, g: 40, b: 34),
                red: Theme.ColorRGB(r: 249, g: 38, b: 114),
                green: Theme.ColorRGB(r: 166, g: 226, b: 46),
                yellow: Theme.ColorRGB(r: 244, g: 191, b: 117),
                blue: Theme.ColorRGB(r: 102, g: 217, b: 239),
                magenta: Theme.ColorRGB(r: 174, g: 129, b: 255),
                cyan: Theme.ColorRGB(r: 161, g: 239, b: 228),
                white: Theme.ColorRGB(r: 248, g: 248, b: 240),
                brightBlack: Theme.ColorRGB(r: 117, g: 113, b: 94),
                brightRed: Theme.ColorRGB(r: 249, g: 38, b: 114),
                brightGreen: Theme.ColorRGB(r: 166, g: 226, b: 46),
                brightYellow: Theme.ColorRGB(r: 244, g: 191, b: 117),
                brightBlue: Theme.ColorRGB(r: 102, g: 217, b: 239),
                brightMagenta: Theme.ColorRGB(r: 174, g: 129, b: 255),
                brightCyan: Theme.ColorRGB(r: 161, g: 239, b: 228),
                brightWhite: Theme.ColorRGB(r: 249, g: 248, b: 245)
            ),
            metadata: nil
        )
    }

    static func oneDark() -> Theme {
        Theme(
            name: "One Dark",
            author: "Atom",
            colors: Theme.ThemeColors(
                background: Theme.ColorRGB(r: 40, g: 44, b: 52),
                foreground: Theme.ColorRGB(r: 171, g: 178, b: 191),
                cursor: Theme.ColorRGB(r: 171, g: 178, b: 191),
                cursorText: nil,
                selection: Theme.ColorRGB(r: 61, g: 66, b: 77),
                black: Theme.ColorRGB(r: 40, g: 44, b: 52),
                red: Theme.ColorRGB(r: 224, g: 108, b: 117),
                green: Theme.ColorRGB(r: 152, g: 195, b: 121),
                yellow: Theme.ColorRGB(r: 229, g: 192, b: 123),
                blue: Theme.ColorRGB(r: 97, g: 175, b: 239),
                magenta: Theme.ColorRGB(r: 198, g: 120, b: 221),
                cyan: Theme.ColorRGB(r: 86, g: 182, b: 194),
                white: Theme.ColorRGB(r: 171, g: 178, b: 191),
                brightBlack: Theme.ColorRGB(r: 92, g: 99, b: 112),
                brightRed: Theme.ColorRGB(r: 224, g: 108, b: 117),
                brightGreen: Theme.ColorRGB(r: 152, g: 195, b: 121),
                brightYellow: Theme.ColorRGB(r: 229, g: 192, b: 123),
                brightBlue: Theme.ColorRGB(r: 97, g: 175, b: 239),
                brightMagenta: Theme.ColorRGB(r: 198, g: 120, b: 221),
                brightCyan: Theme.ColorRGB(r: 86, g: 182, b: 194),
                brightWhite: Theme.ColorRGB(r: 200, g: 204, b: 213)
            ),
            metadata: nil
        )
    }

    static func nord() -> Theme {
        Theme(
            name: "Nord",
            author: "Arctic Ice Studio",
            colors: Theme.ThemeColors(
                background: Theme.ColorRGB(r: 46, g: 52, b: 64),
                foreground: Theme.ColorRGB(r: 216, g: 222, b: 233),
                cursor: Theme.ColorRGB(r: 216, g: 222, b: 233),
                cursorText: nil,
                selection: Theme.ColorRGB(r: 59, g: 66, b: 82),
                black: Theme.ColorRGB(r: 46, g: 52, b: 64),
                red: Theme.ColorRGB(r: 191, g: 97, b: 106),
                green: Theme.ColorRGB(r: 163, g: 190, b: 140),
                yellow: Theme.ColorRGB(r: 235, g: 203, b: 139),
                blue: Theme.ColorRGB(r: 129, g: 161, b: 193),
                magenta: Theme.ColorRGB(r: 180, g: 142, b: 173),
                cyan: Theme.ColorRGB(r: 136, g: 192, b: 208),
                white: Theme.ColorRGB(r: 229, g: 233, b: 240),
                brightBlack: Theme.ColorRGB(r: 76, g: 86, b: 106),
                brightRed: Theme.ColorRGB(r: 191, g: 97, b: 106),
                brightGreen: Theme.ColorRGB(r: 163, g: 190, b: 140),
                brightYellow: Theme.ColorRGB(r: 235, g: 203, b: 139),
                brightBlue: Theme.ColorRGB(r: 129, g: 161, b: 193),
                brightMagenta: Theme.ColorRGB(r: 180, g: 142, b: 173),
                brightCyan: Theme.ColorRGB(r: 143, g: 188, b: 187),
                brightWhite: Theme.ColorRGB(r: 236, g: 239, b: 244)
            ),
            metadata: nil
        )
    }
}

// MARK: - Notification

extension Notification.Name {
    static let themeChanged = Notification.Name("themeChanged")
}
