import Metal
import MetalKit

/// Cursor styles supported by the terminal
enum CursorStyle {
    case block           // Filled block cursor (default)
    case blockOutline    // Hollow block cursor
    case beam            // Vertical beam (I-beam) cursor
    case underline       // Underline cursor
    case hidden          // No cursor visible
}

/// GPU-accelerated cursor rendering
class CursorRenderer {
    private let device: MTLDevice
    private var pipelineState: MTLRenderPipelineState!
    private var vertexBuffer: MTLBuffer?

    var style: CursorStyle = .block
    var color: SIMD4<Float> = SIMD4<Float>(1.0, 1.0, 1.0, 1.0) // White
    var blinkEnabled: Bool = true
    var blinkRate: TimeInterval = 0.5

    private var lastBlinkTime: CFTimeInterval = 0
    private var cursorVisible: Bool = true

    // MARK: - Initialization

    init?(device: MTLDevice) {
        self.device = device

        do {
            try setupPipeline()
            setupBuffers()
        } catch {
            print("Failed to setup cursor renderer: \(error)")
            return nil
        }
    }

    // MARK: - Pipeline Setup

    private func setupPipeline() throws {
        guard let library = device.makeDefaultLibrary() else {
            throw NSError(domain: "CursorRenderer", code: 1,
                         userInfo: [NSLocalizedDescriptionKey: "Failed to load shader library"])
        }

        guard let vertexFunction = library.makeFunction(name: "cursor_vertex"),
              let fragmentFunction = library.makeFunction(name: "cursor_fragment") else {
            throw NSError(domain: "CursorRenderer", code: 2,
                         userInfo: [NSLocalizedDescriptionKey: "Failed to load cursor shader functions"])
        }

        let pipelineDescriptor = MTLRenderPipelineDescriptor()
        pipelineDescriptor.vertexFunction = vertexFunction
        pipelineDescriptor.fragmentFunction = fragmentFunction
        pipelineDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm

        // Enable blending for cursor
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
        // Create quad vertices (will be transformed based on cursor style)
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

    // MARK: - Rendering

    func updateBlink(currentTime: CFTimeInterval) {
        if !blinkEnabled {
            cursorVisible = true
            return
        }

        if currentTime - lastBlinkTime >= blinkRate {
            cursorVisible.toggle()
            lastBlinkTime = currentTime
        }
    }

    func render(
        commandEncoder: MTLRenderCommandEncoder,
        cursorRow: Int,
        cursorCol: Int,
        cellWidth: CGFloat,
        cellHeight: CGFloat,
        viewportSize: CGSize,
        currentTime: CFTimeInterval
    ) {
        guard style != .hidden else { return }

        // Update blink state
        updateBlink(currentTime: currentTime)

        guard cursorVisible else { return }

        // Calculate cursor geometry based on style
        let (position, size) = calculateCursorGeometry(
            row: cursorRow,
            col: cursorCol,
            cellWidth: cellWidth,
            cellHeight: cellHeight
        )

        commandEncoder.setRenderPipelineState(pipelineState)

        // Set uniforms
        var viewportData = SIMD2<Float>(Float(viewportSize.width), Float(viewportSize.height))
        commandEncoder.setVertexBytes(&viewportData, length: MemoryLayout<SIMD2<Float>>.stride, index: 0)

        var positionData = SIMD2<Float>(Float(position.x), Float(position.y))
        commandEncoder.setVertexBytes(&positionData, length: MemoryLayout<SIMD2<Float>>.stride, index: 1)

        var sizeData = SIMD2<Float>(Float(size.width), Float(size.height))
        commandEncoder.setVertexBytes(&sizeData, length: MemoryLayout<SIMD2<Float>>.stride, index: 2)

        var colorData = color
        commandEncoder.setFragmentBytes(&colorData, length: MemoryLayout<SIMD4<Float>>.stride, index: 0)

        var styleData = getStyleFlags()
        commandEncoder.setFragmentBytes(&styleData, length: MemoryLayout<UInt32>.stride, index: 1)

        // Set vertex buffer
        commandEncoder.setVertexBuffer(vertexBuffer, offset: 0, index: 3)

        // Draw cursor
        commandEncoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 6)
    }

    // MARK: - Geometry Calculation

    private func calculateCursorGeometry(
        row: Int,
        col: Int,
        cellWidth: CGFloat,
        cellHeight: CGFloat
    ) -> (position: CGPoint, size: CGSize) {

        let baseX = CGFloat(col) * cellWidth
        let baseY = CGFloat(row) * cellHeight

        switch style {
        case .block, .blockOutline:
            // Full cell
            return (
                position: CGPoint(x: baseX, y: baseY),
                size: CGSize(width: cellWidth, height: cellHeight)
            )

        case .beam:
            // Vertical beam (2 pixels wide)
            let beamWidth: CGFloat = 2.0
            return (
                position: CGPoint(x: baseX, y: baseY),
                size: CGSize(width: beamWidth, height: cellHeight)
            )

        case .underline:
            // Bottom underline (2 pixels tall)
            let underlineHeight: CGFloat = 2.0
            return (
                position: CGPoint(x: baseX, y: baseY + cellHeight - underlineHeight),
                size: CGSize(width: cellWidth, height: underlineHeight)
            )

        case .hidden:
            return (position: .zero, size: .zero)
        }
    }

    private func getStyleFlags() -> UInt32 {
        switch style {
        case .block:
            return 0 // Filled block
        case .blockOutline:
            return 1 // Outline block
        case .beam, .underline:
            return 0 // Filled (beam/underline)
        case .hidden:
            return 0
        }
    }

    // MARK: - Configuration

    func setStyle(_ newStyle: CursorStyle) {
        self.style = newStyle
    }

    func setColor(_ r: Float, _ g: Float, _ b: Float, _ a: Float = 1.0) {
        self.color = SIMD4<Float>(r, g, b, a)
    }

    func setBlink(enabled: Bool, rate: TimeInterval = 0.5) {
        self.blinkEnabled = enabled
        self.blinkRate = rate
        if !enabled {
            cursorVisible = true
        }
    }
}
