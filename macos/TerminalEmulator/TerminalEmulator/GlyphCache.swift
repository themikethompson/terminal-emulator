import Metal
import CoreText
import AppKit

/// Manages glyph rasterization and texture atlas for efficient GPU rendering
class GlyphCache {
    // MARK: - Types

    struct GlyphInfo {
        let texCoords: SIMD4<Float>  // x, y, width, height in normalized texture coordinates (0-1)
        let size: CGSize              // Actual glyph size in pixels
        let offset: CGPoint           // Rendering offset
    }

    private struct CacheKey: Hashable {
        let character: UnicodeScalar
        let bold: Bool
        let italic: Bool
    }

    // MARK: - Properties

    private let device: MTLDevice
    private let font: NSFont
    private let boldFont: NSFont
    private let italicFont: NSFont
    private let boldItalicFont: NSFont

    private(set) var texture: MTLTexture!
    private var cache: [CacheKey: GlyphInfo] = [:]

    // Texture atlas configuration
    private let atlasSize: Int = 2048  // 2048x2048 texture
    private var currentX: Int = 0
    private var currentY: Int = 0
    private var rowHeight: Int = 0
    private var atlasPixels: [UInt8]

    // MARK: - Initialization

    init(device: MTLDevice, font: NSFont) {
        self.device = device
        self.font = font

        // Create font variants
        let fontManager = NSFontManager.shared
        self.boldFont = fontManager.convert(font, toHaveTrait: .boldFontMask)
        self.italicFont = fontManager.convert(font, toHaveTrait: .italicFontMask)
        self.boldItalicFont = fontManager.convert(font, toHaveTrait: [.boldFontMask, .italicFontMask])

        // Initialize atlas pixel buffer (RGBA8)
        self.atlasPixels = [UInt8](repeating: 0, count: atlasSize * atlasSize * 4)

        // Create texture
        setupTexture()

        // Pre-cache common ASCII characters
        precacheASCII()
    }

    // MARK: - Setup

    private func setupTexture() {
        let textureDescriptor = MTLTextureDescriptor()
        textureDescriptor.pixelFormat = .rgba8Unorm
        textureDescriptor.width = atlasSize
        textureDescriptor.height = atlasSize
        textureDescriptor.usage = [.shaderRead]
        textureDescriptor.storageMode = .shared

        guard let tex = device.makeTexture(descriptor: textureDescriptor) else {
            fatalError("Failed to create glyph atlas texture")
        }

        self.texture = tex
    }

    private func precacheASCII() {
        // Cache printable ASCII characters (32-126)
        for scalar in 32...126 {
            if let unicodeScalar = UnicodeScalar(scalar) {
                _ = getGlyph(for: unicodeScalar, bold: false, italic: false)
            }
        }

        // Also cache common extended characters
        let commonChars: [UnicodeScalar] = ["─", "│", "┌", "┐", "└", "┘", "├", "┤", "┬", "┴", "┼",
                                            "═", "║", "╔", "╗", "╚", "╝", "╠", "╣", "╦", "╩", "╬"]
        for char in commonChars {
            _ = getGlyph(for: char, bold: false, italic: false)
        }
    }

    // MARK: - Public API

    /// Get glyph from cache or rasterize and cache it
    func getGlyph(for character: UnicodeScalar, bold: Bool, italic: Bool) -> GlyphInfo {
        let key = CacheKey(character: character, bold: bold, italic: italic)

        if let cached = cache[key] {
            return cached
        }

        // Rasterize glyph and add to atlas
        let info = rasterizeGlyph(character, bold: bold, italic: italic)
        cache[key] = info
        return info
    }

    // MARK: - Glyph Rasterization

    private func rasterizeGlyph(_ character: UnicodeScalar, bold: Bool, italic: Bool) -> GlyphInfo {
        // Select appropriate font
        let selectedFont: NSFont
        if bold && italic {
            selectedFont = boldItalicFont
        } else if bold {
            selectedFont = boldFont
        } else if italic {
            selectedFont = italicFont
        } else {
            selectedFont = font
        }

        // Create attributed string
        let string = String(character)
        let attributes: [NSAttributedString.Key: Any] = [
            .font: selectedFont,
            .foregroundColor: NSColor.white
        ]
        let attributedString = NSAttributedString(string: string, attributes: attributes)

        // Measure glyph
        let size = attributedString.size()
        let width = Int(ceil(size.width)) + 2  // Add 1px padding on each side
        let height = Int(ceil(size.height)) + 2

        // Create bitmap context
        guard width > 0 && height > 0,
              let context = CGContext(
                data: nil,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: width * 4,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
              ) else {
            // Return empty glyph for characters that can't be rendered
            return GlyphInfo(texCoords: SIMD4<Float>(0, 0, 0, 0),
                           size: .zero,
                           offset: .zero)
        }

        // Clear context
        context.clear(CGRect(x: 0, y: 0, width: width, height: height))

        // Draw text
        context.setAllowsAntialiasing(true)
        context.setShouldAntialias(true)
        context.setAllowsFontSmoothing(true)
        context.setShouldSmoothFonts(true)

        let nsContext = NSGraphicsContext(cgContext: context, flipped: false)
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = nsContext

        attributedString.draw(at: CGPoint(x: 1, y: 1))

        NSGraphicsContext.restoreGraphicsState()

        // Get pixel data
        guard let data = context.data else {
            return GlyphInfo(texCoords: SIMD4<Float>(0, 0, 0, 0),
                           size: .zero,
                           offset: .zero)
        }

        // Check if we need to move to next row in atlas
        if currentX + width > atlasSize {
            currentX = 0
            currentY += rowHeight
            rowHeight = 0
        }

        // Check if we've run out of space
        if currentY + height > atlasSize {
            print("Warning: Glyph atlas is full! Consider increasing atlas size.")
            return GlyphInfo(texCoords: SIMD4<Float>(0, 0, 0, 0),
                           size: .zero,
                           offset: .zero)
        }

        // Copy glyph pixels into atlas
        let pixels = data.bindMemory(to: UInt8.self, capacity: width * height * 4)
        for y in 0..<height {
            let srcOffset = y * width * 4
            let dstY = currentY + y
            let dstOffset = (dstY * atlasSize + currentX) * 4
            let srcRange = srcOffset..<(srcOffset + width * 4)
            atlasPixels.replaceSubrange(dstOffset..<(dstOffset + width * 4),
                                       with: UnsafeBufferPointer(start: pixels + srcOffset, count: width * 4))
        }

        // Update texture region
        let region = MTLRegion(
            origin: MTLOrigin(x: currentX, y: currentY, z: 0),
            size: MTLSize(width: width, height: height, depth: 1)
        )

        atlasPixels.withUnsafeBytes { ptr in
            let basePtr = ptr.baseAddress!.advanced(by: (currentY * atlasSize + currentX) * 4)
            texture.replace(region: region,
                          mipmapLevel: 0,
                          withBytes: basePtr,
                          bytesPerRow: atlasSize * 4)
        }

        // Calculate texture coordinates (normalized 0-1)
        let texX = Float(currentX) / Float(atlasSize)
        let texY = Float(currentY) / Float(atlasSize)
        let texW = Float(width) / Float(atlasSize)
        let texH = Float(height) / Float(atlasSize)

        let glyphInfo = GlyphInfo(
            texCoords: SIMD4<Float>(texX, texY, texW, texH),
            size: CGSize(width: width, height: height),
            offset: CGPoint(x: -1, y: -1)  // Account for padding
        )

        // Update atlas position
        currentX += width
        rowHeight = max(rowHeight, height)

        return glyphInfo
    }

    // MARK: - Debugging

    /// Export atlas to PNG for debugging
    func exportAtlas(to url: URL) {
        guard let context = CGContext(
            data: &atlasPixels,
            width: atlasSize,
            height: atlasSize,
            bitsPerComponent: 8,
            bytesPerRow: atlasSize * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ), let image = context.makeImage() else {
            print("Failed to create image from atlas")
            return
        }

        let bitmapRep = NSBitmapImageRep(cgImage: image)
        guard let pngData = bitmapRep.representation(using: .png, properties: [:]) else {
            print("Failed to create PNG data")
            return
        }

        try? pngData.write(to: url)
        print("Atlas exported to \(url.path)")
    }
}
