import Foundation
import CoreText
import AppKit

/// Handles ligature rendering for programming fonts (Fira Code, JetBrains Mono, etc.)
/// Uses CoreText's built-in ligature support
class LigatureHandler {
    // MARK: - Types

    struct LigatureSequence {
        let characters: String          // Original character sequence (e.g., "=>")
        let glyphCount: Int            // Number of glyphs produced
        let width: CGFloat             // Total width in cells
    }

    // MARK: - Properties

    private let font: NSFont
    var enabled: Bool = true

    // Common programming ligatures
    private static let commonLigatures: Set<String> = [
        // Arrows
        "->", "=>", "<-", "<=", ">=", "==", "!=", "===", "!==",
        // Operators
        "++", "--", "**", "//", "/*", "*/", "||", "&&", "??",
        // Special
        "::", "##", "###", "####", "...", "..", "!!", "??"
    ]

    // MARK: - Initialization

    init(font: NSFont) {
        self.font = font
    }

    // MARK: - Ligature Detection

    /// Check if a sequence of characters should be rendered as a ligature
    func shouldApplyLigature(at text: String, startIndex: Int, maxLength: Int = 4) -> LigatureSequence? {
        guard enabled else { return nil }

        // Try progressively longer sequences
        for length in stride(from: min(maxLength, text.count - startIndex), through: 2, by: -1) {
            let endIndex = text.index(text.startIndex, offsetBy: startIndex + length)
            let startIdx = text.index(text.startIndex, offsetBy: startIndex)

            guard endIndex <= text.endIndex else { continue }

            let substring = String(text[startIdx..<endIndex])

            // Check if this is a known ligature
            if Self.commonLigatures.contains(substring) {
                // Verify font supports this ligature
                if let sequence = renderLigature(substring) {
                    return sequence
                }
            }
        }

        return nil
    }

    // MARK: - Rendering

    /// Render a ligature sequence and return its properties
    private func renderLigature(_ characters: String) -> LigatureSequence? {
        // Create attributed string with ligatures enabled
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .ligature: 1  // Enable standard ligatures
        ]

        let attributedString = NSAttributedString(string: characters, attributes: attributes)

        // Get the glyph run
        let line = CTLineCreateWithAttributedString(attributedString)
        guard let runs = CTLineGetGlyphRuns(line) as? [CTRun],
              let run = runs.first else {
            return nil
        }

        let glyphCount = CTRunGetGlyphCount(run)

        // If glyph count < character count, a ligature was formed
        if glyphCount < characters.count {
            let width = attributedString.size().width

            return LigatureSequence(
                characters: characters,
                glyphCount: glyphCount,
                width: width
            )
        }

        return nil
    }

    /// Render ligature to a bitmap context
    func renderLigatureToBitmap(_ characters: String, font: NSFont) -> (CGContext, CGSize)? {
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .ligature: 1,
            .foregroundColor: NSColor.white
        ]

        let attributedString = NSAttributedString(string: characters, attributes: attributes)
        let size = attributedString.size()

        let width = Int(ceil(size.width)) + 4  // Padding
        let height = Int(ceil(size.height)) + 4

        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return nil
        }

        // Clear and setup context
        context.clear(CGRect(x: 0, y: 0, width: width, height: height))
        context.setAllowsAntialiasing(true)
        context.setShouldAntialias(true)

        // Draw ligature
        let nsContext = NSGraphicsContext(cgContext: context, flipped: false)
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = nsContext

        attributedString.draw(at: CGPoint(x: 2, y: 2))

        NSGraphicsContext.restoreGraphicsState()

        return (context, CGSize(width: width, height: height))
    }

    // MARK: - Font Capability Detection

    /// Check if the current font supports ligatures
    func fontSupportsLigatures() -> Bool {
        // Test with a common ligature
        if let _ = renderLigature("->") {
            return true
        }

        if let _ = renderLigature("==") {
            return true
        }

        return false
    }

    /// Get list of supported ligatures from font
    func getSupportedLigatures() -> [String] {
        var supported: [String] = []

        for ligature in Self.commonLigatures {
            if renderLigature(ligature) != nil {
                supported.append(ligature)
            }
        }

        return supported.sorted()
    }
}

// MARK: - Ligature-Aware GlyphCache Extension

/// Extended glyph info for ligatures
struct LigatureGlyphInfo {
    let texCoords: SIMD4<Float>
    let size: CGSize
    let characterCount: Int  // How many characters this ligature represents
}

// MARK: - Programming Font Recommendations

extension LigatureHandler {
    /// Fonts known to have excellent ligature support
    static let recommendedFonts: [(String, String)] = [
        ("FiraCode-Regular", "Fira Code - Excellent ligature support"),
        ("JetBrainsMono-Regular", "JetBrains Mono - Clean ligatures"),
        ("CascadiaCode", "Cascadia Code - Microsoft's programming font"),
        ("Hasklig-Regular", "Hasklig - Ligatures for Haskell/functional programming"),
        ("MonoLisa-Regular", "MonoLisa - Premium font with ligatures"),
        ("VictorMono-Regular", "Victor Mono - Cursive italics + ligatures"),
        ("Iosevka", "Iosevka - Customizable with ligatures")
    ]

    /// Check if a font name indicates ligature support
    static func fontLikelySupportsLigatures(name: String) -> Bool {
        let ligatureFonts = ["fira", "jetbrains", "cascadia", "hasklig", "monolisa", "victor", "iosevka"]
        let lowerName = name.lowercased()

        return ligatureFonts.contains { lowerName.contains($0) }
    }
}

// MARK: - Configuration

struct LigatureConfiguration {
    /// Enable/disable ligatures globally
    var enabled: Bool = true

    /// Specific ligatures to disable (useful if some are ambiguous)
    var disabledLigatures: Set<String> = []

    /// Minimum context needed before rendering ligature (prevents mid-word ligatures)
    var requireWordBoundary: Bool = false

    /// Allow ligatures to span multiple cells (true for most terminals)
    var allowMultiCell: Bool = true
}
