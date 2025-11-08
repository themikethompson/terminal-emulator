import Metal
import MetalKit
import CoreText
import AppKit

/// GPU-accelerated terminal renderer using Metal
/// Renders terminal cells using instanced drawing with glyph texture atlas
class MetalRenderer {
    // MARK: - Metal Resources
    private let device: MTLDevice
    private let commandQueue: MTLCommandQueue
    private var pipelineState: MTLRenderPipelineState!
    private var vertexBuffer: MTLBuffer?
    private var cellDataBuffer: MTLBuffer?

    // MARK: - Glyph Cache
    private let glyphCache: GlyphCache

    // MARK: - Cursor Renderer
    private let cursorRenderer: CursorRenderer

    // MARK: - Scroll Animator
    private let scrollAnimator: ScrollAnimator

    // MARK: - Terminal Dimensions
    private var rows: Int = 24
    private var cols: Int = 80
    private var cellWidth: CGFloat = 9.0
    private var cellHeight: CGFloat = 18.0

    // MARK: - Cell Data Structure (must match shader)
    struct CellData {
        var position: SIMD2<Float>      // x, y position in pixels
        var glyphTexCoords: SIMD4<Float> // x, y, width, height in texture space (0-1)
        var foreground: SIMD4<Float>    // RGBA
        var background: SIMD4<Float>    // RGBA
        var flags: UInt32               // bold, italic, underline, etc.
        var _padding: SIMD3<UInt32>     // Alignment padding to 16-byte boundary
    }

    // MARK: - Initialization
    init?(font: NSFont) {
        guard let device = MTLCreateSystemDefaultDevice() else {
            print("Metal is not supported on this device")
            return nil
        }

        self.device = device

        guard let queue = device.makeCommandQueue() else {
            print("Failed to create Metal command queue")
            return nil
        }
        self.commandQueue = queue

        // Initialize glyph cache
        self.glyphCache = GlyphCache(device: device, font: font)

        // Initialize cursor renderer
        guard let cursor = CursorRenderer(device: device) else {
            print("Failed to create cursor renderer")
            return nil
        }
        self.cursorRenderer = cursor

        // Initialize scroll animator
        self.scrollAnimator = ScrollAnimator()

        // Calculate cell dimensions from font
        let attributes: [NSAttributedString.Key: Any] = [.font: font]
        let testString = NSAttributedString(string: "M", attributes: attributes)
        let size = testString.size()
        self.cellWidth = ceil(size.width)
        self.cellHeight = ceil(size.height)

        // Setup Metal pipeline
        do {
            try setupPipeline()
            setupBuffers()
        } catch {
            print("Failed to setup Metal pipeline: \(error)")
            return nil
        }
    }

    // MARK: - Pipeline Setup
    private func setupPipeline() throws {
        // Load shader library
        guard let library = device.makeDefaultLibrary() else {
            throw NSError(domain: "MetalRenderer", code: 1,
                         userInfo: [NSLocalizedDescriptionKey: "Failed to load shader library"])
        }

        guard let vertexFunction = library.makeFunction(name: "vertex_main"),
              let fragmentFunction = library.makeFunction(name: "fragment_main") else {
            throw NSError(domain: "MetalRenderer", code: 2,
                         userInfo: [NSLocalizedDescriptionKey: "Failed to load shader functions"])
        }

        // Create pipeline descriptor
        let pipelineDescriptor = MTLRenderPipelineDescriptor()
        pipelineDescriptor.vertexFunction = vertexFunction
        pipelineDescriptor.fragmentFunction = fragmentFunction
        pipelineDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm

        // Enable blending for text rendering
        pipelineDescriptor.colorAttachments[0].isBlendingEnabled = true
        pipelineDescriptor.colorAttachments[0].rgbBlendOperation = .add
        pipelineDescriptor.colorAttachments[0].alphaBlendOperation = .add
        pipelineDescriptor.colorAttachments[0].sourceRGBBlendFactor = .sourceAlpha
        pipelineDescriptor.colorAttachments[0].sourceAlphaBlendFactor = .sourceAlpha
        pipelineDescriptor.colorAttachments[0].destinationRGBBlendFactor = .oneMinusSourceAlpha
        pipelineDescriptor.colorAttachments[0].destinationAlphaBlendFactor = .oneMinusSourceAlpha

        pipelineState = try device.makeRenderPipelineState(descriptor: pipelineDescriptor)
    }

    private func setupBuffers() {
        // Create static vertex buffer for a quad (2 triangles)
        let vertices: [SIMD2<Float>] = [
            SIMD2<Float>(0.0, 0.0), // top-left
            SIMD2<Float>(1.0, 0.0), // top-right
            SIMD2<Float>(0.0, 1.0), // bottom-left
            SIMD2<Float>(1.0, 0.0), // top-right
            SIMD2<Float>(1.0, 1.0), // bottom-right
            SIMD2<Float>(0.0, 1.0)  // bottom-left
        ]

        vertexBuffer = device.makeBuffer(bytes: vertices,
                                        length: vertices.count * MemoryLayout<SIMD2<Float>>.stride,
                                        options: .storageModeShared)
    }

    // MARK: - Public API

    /// Update terminal dimensions
    func resize(rows: Int, cols: Int, scrollbackLines: Int = 10000) {
        self.rows = rows
        self.cols = cols

        // Update scroll animator with new dimensions
        scrollAnimator.configure(
            scrollbackLines: scrollbackLines,
            visibleLines: rows,
            lineHeight: cellHeight
        )
    }

    /// Get cell dimensions
    func getCellSize() -> (width: CGFloat, height: CGFloat) {
        return (cellWidth, cellHeight)
    }

    /// Render terminal grid to Metal texture/drawable
    func render(terminal: TerminalCore,
                to drawable: CAMetalDrawable,
                viewportSize: CGSize,
                currentTime: CFTimeInterval = CACurrentMediaTime()) {

        // Update scroll animation
        let scrollOffset = scrollAnimator.update(currentTime: currentTime)

        // Calculate which rows to render (accounting for scroll)
        // For now, render visible rows only (scrollback integration TODO in Phase 5)
        let scrollLine = scrollAnimator.getScrollLine()

        // Prepare cell data for all visible cells
        var cellDataArray: [CellData] = []
        cellDataArray.reserveCapacity(rows * cols)

        for row in 0..<rows {
            guard let rowData = terminal.getRow(row) else { continue }

            for col in 0..<cols {
                guard col < rowData.count else { break }
                let cell = rowData[col]

                // Get glyph from cache (or cache it if not present)
                let char = cell.character
                let glyphInfo = glyphCache.getGlyph(for: char, bold: cell.isBold, italic: cell.isItalic)

                // Calculate cell position in pixels
                let x = Float(col) * Float(cellWidth)
                let y = Float(row) * Float(cellHeight)

                // Convert colors to SIMD4<Float>
                let fg = colorToFloat4(cell.foreground)
                let bg = colorToFloat4(cell.background)

                let cellData = CellData(
                    position: SIMD2<Float>(x, y),
                    glyphTexCoords: glyphInfo.texCoords,
                    foreground: fg,
                    background: bg,
                    flags: cell.flags,
                    _padding: SIMD3<UInt32>(0, 0, 0)
                )

                cellDataArray.append(cellData)
            }
        }

        // Upload cell data to GPU
        if !cellDataArray.isEmpty {
            cellDataBuffer = device.makeBuffer(bytes: cellDataArray,
                                              length: cellDataArray.count * MemoryLayout<CellData>.stride,
                                              options: .storageModeShared)
        }

        // Create command buffer and render pass
        guard let commandBuffer = commandQueue.makeCommandBuffer(),
              let cellBuffer = cellDataBuffer else { return }

        let renderPassDescriptor = MTLRenderPassDescriptor()
        renderPassDescriptor.colorAttachments[0].texture = drawable.texture
        renderPassDescriptor.colorAttachments[0].loadAction = .clear
        renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColor(red: 0.0, green: 0.0, blue: 0.0, alpha: 1.0)
        renderPassDescriptor.colorAttachments[0].storeAction = .store

        guard let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) else { return }

        renderEncoder.setRenderPipelineState(pipelineState)

        // Set viewport size uniform
        var viewportData = SIMD2<Float>(Float(viewportSize.width), Float(viewportSize.height))
        renderEncoder.setVertexBytes(&viewportData, length: MemoryLayout<SIMD2<Float>>.stride, index: 0)

        // Set cell dimensions uniform
        var cellDims = SIMD2<Float>(Float(cellWidth), Float(cellHeight))
        renderEncoder.setVertexBytes(&cellDims, length: MemoryLayout<SIMD2<Float>>.stride, index: 1)

        // Set vertex buffer (quad)
        renderEncoder.setVertexBuffer(vertexBuffer, offset: 0, index: 2)

        // Set cell data buffer
        renderEncoder.setVertexBuffer(cellBuffer, offset: 0, index: 3)

        // Set glyph texture
        renderEncoder.setFragmentTexture(glyphCache.texture, index: 0)

        // Draw all cells with instanced rendering
        renderEncoder.drawPrimitives(type: .triangle,
                                    vertexStart: 0,
                                    vertexCount: 6,
                                    instanceCount: cellDataArray.count)

        // Draw cursor
        let cursorPos = terminal.cursorPosition
        cursorRenderer.render(
            commandEncoder: renderEncoder,
            cursorRow: Int(cursorPos.row),
            cursorCol: Int(cursorPos.col),
            cellWidth: cellWidth,
            cellHeight: cellHeight,
            viewportSize: viewportSize,
            currentTime: currentTime
        )

        renderEncoder.endEncoding()

        commandBuffer.present(drawable)
        commandBuffer.commit()
    }

    // MARK: - Cursor Configuration

    /// Set cursor style
    func setCursorStyle(_ style: CursorStyle) {
        cursorRenderer.setStyle(style)
    }

    /// Set cursor color
    func setCursorColor(_ r: Float, _ g: Float, _ b: Float, _ a: Float = 1.0) {
        cursorRenderer.setColor(r, g, b, a)
    }

    /// Enable/disable cursor blinking
    func setCursorBlink(enabled: Bool, rate: TimeInterval = 0.5) {
        cursorRenderer.setBlink(enabled: enabled, rate: rate)
    }

    // MARK: - Scroll Control

    /// Get the scroll animator for external control
    func getScrollAnimator() -> ScrollAnimator {
        return scrollAnimator
    }

    /// Scroll by a number of lines
    func scrollBy(lines: Int) {
        scrollAnimator.scrollBy(lines: lines)
    }

    /// Scroll to top (most recent content)
    func scrollToTop() {
        scrollAnimator.scrollToTop()
    }

    /// Check if actively scrolling
    var isScrolling: Bool {
        return scrollAnimator.needsUpdate
    }

    // MARK: - Helper Methods

    private func colorToFloat4(_ color: (r: UInt8, g: UInt8, b: UInt8)) -> SIMD4<Float> {
        return SIMD4<Float>(
            Float(color.r) / 255.0,
            Float(color.g) / 255.0,
            Float(color.b) / 255.0,
            1.0
        )
    }
}

// MARK: - Terminal Cell Extension
extension TerminalCore.Cell {
    var isBold: Bool { (flags & 0x01) != 0 }
    var isItalic: Bool { (flags & 0x02) != 0 }
    var isUnderline: Bool { (flags & 0x04) != 0 }
}
