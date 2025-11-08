import Cocoa

@main
class AppDelegate: NSObject, NSApplicationDelegate {

    var windowController: TerminalWindowController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Create and show terminal window
        windowController = TerminalWindowController()
        windowController?.showWindow(nil)
        windowController?.window?.makeKeyAndOrderFront(nil)
    }

    func applicationWillTerminate(_ notification: Notification) {
        // Cleanup
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        return true
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }
}
