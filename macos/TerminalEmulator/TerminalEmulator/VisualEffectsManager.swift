import Cocoa
import AppKit

/// Manages visual effects for the terminal window (blur, transparency, vibrancy)
class VisualEffectsManager {
    // MARK: - Properties

    private weak var window: NSWindow?
    private var visualEffectView: NSVisualEffectView?

    /// Background opacity (0.0 = fully transparent, 1.0 = fully opaque)
    var opacity: CGFloat = 1.0 {
        didSet {
            updateOpacity()
        }
    }

    /// Blur intensity (uses macOS native blur)
    var blurEnabled: Bool = false {
        didSet {
            updateBlur()
        }
    }

    /// Blur material (different visual styles)
    var blurMaterial: NSVisualEffectView.Material = .hudWindow {
        didSet {
            updateBlurMaterial()
        }
    }

    /// Vibrancy (allows content behind window to show through)
    var vibrancy: Bool = false {
        didSet {
            updateVibrancy()
        }
    }

    // MARK: - Initialization

    init(window: NSWindow) {
        self.window = window
        setupWindow()
    }

    // MARK: - Setup

    private func setupWindow() {
        guard let window = window else { return }

        // Make window transparent-capable
        window.isOpaque = false
        window.backgroundColor = .clear

        // Enable full-size content view
        window.styleMask.insert(.fullSizeContentView)

        // Optionally hide title bar (for clean look)
        // window.titlebarAppearsTransparent = true
        // window.titleVisibility = .hidden
    }

    /// Install visual effect view as background
    func installVisualEffectView(in contentView: NSView) {
        // Remove existing visual effect view if any
        visualEffectView?.removeFromSuperview()

        // Create new visual effect view
        let effectView = NSVisualEffectView(frame: contentView.bounds)
        effectView.autoresizingMask = [.width, .height]
        effectView.blendingMode = .behindWindow
        effectView.state = .active

        // Insert as background
        contentView.addSubview(effectView, positioned: .below, relativeTo: nil)

        self.visualEffectView = effectView

        // Apply current settings
        updateBlur()
        updateBlurMaterial()
        updateOpacity()
        updateVibrancy()
    }

    // MARK: - Visual Effect Updates

    private func updateOpacity() {
        guard let window = window else { return }

        window.alphaValue = opacity

        // Also update background color alpha
        if opacity < 1.0 {
            window.backgroundColor = NSColor.black.withAlphaComponent(opacity)
        } else {
            window.backgroundColor = .black
        }
    }

    private func updateBlur() {
        guard let effectView = visualEffectView else { return }

        if blurEnabled {
            effectView.material = blurMaterial
            effectView.isHidden = false
        } else {
            effectView.isHidden = true
        }
    }

    private func updateBlurMaterial() {
        guard let effectView = visualEffectView else { return }
        effectView.material = blurMaterial
    }

    private func updateVibrancy() {
        guard let effectView = visualEffectView else { return }

        if vibrancy {
            effectView.blendingMode = .withinWindow
            effectView.state = .active
        } else {
            effectView.blendingMode = .behindWindow
            effectView.state = .active
        }
    }

    // MARK: - Preset Configurations

    /// Apply a preset configuration
    func applyPreset(_ preset: VisualEffectPreset) {
        switch preset {
        case .none:
            blurEnabled = false
            opacity = 1.0
            vibrancy = false

        case .subtle:
            blurEnabled = true
            blurMaterial = .hudWindow
            opacity = 0.95
            vibrancy = false

        case .moderate:
            blurEnabled = true
            blurMaterial = .menu
            opacity = 0.90
            vibrancy = false

        case .heavy:
            blurEnabled = true
            blurMaterial = .popover
            opacity = 0.80
            vibrancy = true

        case .ultraBlur:
            blurEnabled = true
            blurMaterial = .sidebar
            opacity = 0.70
            vibrancy = true

        case .custom(let opacity, let material, let vibrancy):
            self.blurEnabled = opacity < 1.0 || vibrancy
            self.blurMaterial = material
            self.opacity = opacity
            self.vibrancy = vibrancy
        }
    }
}

// MARK: - Visual Effect Presets

enum VisualEffectPreset {
    case none                       // Fully opaque, no effects
    case subtle                     // 95% opacity, light blur
    case moderate                   // 90% opacity, medium blur
    case heavy                      // 80% opacity, heavy blur with vibrancy
    case ultraBlur                  // 70% opacity, maximum blur
    case custom(opacity: CGFloat, material: NSVisualEffectView.Material, vibrancy: Bool)
}

// MARK: - Available Blur Materials

extension VisualEffectsManager {
    /// Get list of available blur materials with descriptions
    static var availableMaterials: [(NSVisualEffectView.Material, String)] {
        return [
            (.titlebar, "Titlebar - Matches window titlebar"),
            (.selection, "Selection - For selected content"),
            (.menu, "Menu - Menu-style blur"),
            (.popover, "Popover - Popover-style blur"),
            (.sidebar, "Sidebar - Sidebar blur"),
            (.headerView, "Header View - Header blur"),
            (.sheet, "Sheet - Sheet-style blur"),
            (.windowBackground, "Window Background - General window blur"),
            (.hudWindow, "HUD Window - Heads-up display blur"),
            (.fullScreenUI, "Full Screen UI - Full screen mode"),
            (.toolTip, "Tooltip - Tooltip style"),
            (.contentBackground, "Content Background - Content area"),
            (.underWindowBackground, "Under Window - Behind window"),
            (.underPageBackground, "Under Page - Behind page")
        ]
    }
}

// MARK: - Animation Support

extension VisualEffectsManager {
    /// Animate opacity change
    func animateOpacity(to newOpacity: CGFloat, duration: TimeInterval = 0.3) {
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = duration
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            window?.animator().alphaValue = newOpacity
        }, completionHandler: {
            self.opacity = newOpacity
        })
    }

    /// Animate blur transition
    func animateBlur(enabled: Bool, duration: TimeInterval = 0.3) {
        guard let effectView = visualEffectView else { return }

        if enabled {
            effectView.isHidden = false
            effectView.alphaValue = 0.0

            NSAnimationContext.runAnimationGroup({ context in
                context.duration = duration
                effectView.animator().alphaValue = 1.0
            }, completionHandler: {
                self.blurEnabled = enabled
            })
        } else {
            NSAnimationContext.runAnimationGroup({ context in
                context.duration = duration
                effectView.animator().alphaValue = 0.0
            }, completionHandler: {
                effectView.isHidden = true
                self.blurEnabled = enabled
            })
        }
    }
}
