import Cocoa

class TerminalWindowController: NSWindowController {

    convenience init() {
        // Create window
        let window = NSWindow(
            contentRect: NSRect(x: 100, y: 100, width: 800, height: 600),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )

        window.title = "Terminal"
        window.minSize = NSSize(width: 400, height: 300)

        // Create view controller
        let viewController = TerminalViewController()
        window.contentViewController = viewController

        self.init(window: window)
    }

    override func windowDidLoad() {
        super.windowDidLoad()

        // Make terminal the first responder for keyboard input
        window?.makeFirstResponder(window?.contentViewController?.view)
    }
}
