import Foundation
import QuartzCore

/// Handles smooth scrolling animations for terminal content
class ScrollAnimator {
    // MARK: - Properties

    /// Current scroll offset in pixels (0 = no scroll, positive = scrolled up)
    private(set) var currentOffset: CGFloat = 0

    /// Target scroll offset we're animating towards
    private var targetOffset: CGFloat = 0

    /// Animation parameters
    var duration: TimeInterval = 0.15  // 150ms for smooth but responsive
    var timingFunction: CAMediaTimingFunction = CAMediaTimingFunction(name: .easeOut)

    /// Animation state
    private var animationStartTime: CFTimeInterval = 0
    private var animationStartOffset: CGFloat = 0
    private var isAnimating: Bool = false

    // Scrollback properties
    private var scrollbackLines: Int = 0      // Number of lines in scrollback buffer
    private var visibleLines: Int = 24        // Number of visible lines (rows)
    private var lineHeight: CGFloat = 18.0    // Height of one line in pixels

    // MARK: - Configuration

    func configure(scrollbackLines: Int, visibleLines: Int, lineHeight: CGFloat) {
        self.scrollbackLines = scrollbackLines
        self.visibleLines = visibleLines
        self.lineHeight = lineHeight
    }

    // MARK: - Scrolling API

    /// Scroll by a delta amount (negative = scroll down, positive = scroll up)
    func scrollBy(lines: Int) {
        let deltaPixels = CGFloat(lines) * lineHeight
        scrollTo(offset: targetOffset + deltaPixels)
    }

    /// Scroll to a specific offset (in pixels)
    func scrollTo(offset: CGFloat) {
        // Clamp to valid range
        let maxScroll = CGFloat(scrollbackLines) * lineHeight
        let clampedOffset = min(max(offset, 0), maxScroll)

        if clampedOffset != targetOffset {
            targetOffset = clampedOffset
            startAnimation()
        }
    }

    /// Scroll to top (newest content)
    func scrollToTop() {
        scrollTo(offset: 0)
    }

    /// Scroll to bottom (oldest content in scrollback)
    func scrollToBottom() {
        let maxScroll = CGFloat(scrollbackLines) * lineHeight
        scrollTo(offset: maxScroll)
    }

    /// Jump immediately to offset without animation
    func jumpTo(offset: CGFloat) {
        let maxScroll = CGFloat(scrollbackLines) * lineHeight
        let clampedOffset = min(max(offset, 0), maxScroll)

        currentOffset = clampedOffset
        targetOffset = clampedOffset
        isAnimating = false
    }

    // MARK: - Animation

    private func startAnimation() {
        animationStartTime = CACurrentMediaTime()
        animationStartOffset = currentOffset
        isAnimating = true
    }

    /// Update animation state and return current offset
    /// Call this every frame to get the interpolated offset
    func update(currentTime: CFTimeInterval) -> CGFloat {
        guard isAnimating else {
            return currentOffset
        }

        let elapsed = currentTime - animationStartTime
        let progress = min(elapsed / duration, 1.0)

        if progress >= 1.0 {
            // Animation complete
            currentOffset = targetOffset
            isAnimating = false
            return currentOffset
        }

        // Apply easing function
        let easedProgress = applyEasing(progress)

        // Interpolate
        let delta = targetOffset - animationStartOffset
        currentOffset = animationStartOffset + (delta * easedProgress)

        return currentOffset
    }

    private func applyEasing(_ t: CGFloat) -> CGFloat {
        // Ease-out cubic: t * t * (3 - 2 * t)
        // This gives a smooth deceleration
        return t * t * (3.0 - 2.0 * t)
    }

    /// Check if currently animating
    var needsUpdate: Bool {
        return isAnimating
    }

    /// Get the scroll offset as a line number (for rendering)
    func getScrollLine() -> Int {
        return Int(round(currentOffset / lineHeight))
    }

    /// Get the fractional scroll position (for sub-pixel scrolling)
    func getFractionalScroll() -> (line: Int, fraction: CGFloat) {
        let lineNumber = Int(floor(currentOffset / lineHeight))
        let fraction = (currentOffset / lineHeight) - CGFloat(lineNumber)
        return (lineNumber, fraction)
    }
}

// MARK: - Mouse/Trackpad Input Helper

extension ScrollAnimator {
    /// Handle scroll wheel input
    /// Returns true if scroll was handled
    func handleScrollWheel(deltaY: CGFloat, isPixelBased: Bool = false) -> Bool {
        let scrollAmount: CGFloat

        if isPixelBased {
            // Precise scrolling (trackpad)
            scrollAmount = deltaY
        } else {
            // Line-based scrolling (mouse wheel)
            scrollAmount = deltaY * lineHeight
        }

        scrollTo(offset: currentOffset - scrollAmount)
        return true
    }

    /// Handle page up/down
    func handlePageScroll(direction: ScrollDirection) {
        let pagelines = visibleLines - 1  // Leave one line overlap
        switch direction {
        case .up:
            scrollBy(lines: pagelines)
        case .down:
            scrollBy(lines: -pagelines)
        }
    }
}

enum ScrollDirection {
    case up
    case down
}
