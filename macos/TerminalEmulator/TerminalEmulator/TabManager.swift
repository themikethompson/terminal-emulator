import Cocoa

/// Manages tabs in the terminal window
class TabManager: NSObject {
    // MARK: - Properties

    private weak var window: NSWindow?
    private var tabViewController: NSTabViewController?
    private var tabs: [TerminalTab] = []

    var currentTab: TerminalTab? {
        return tabs.first { $0.isSelected }
    }

    var tabCount: Int {
        return tabs.count
    }

    // MARK: - Initialization

    init(window: NSWindow) {
        self.window = window
        super.init()
        setupTabViewController()
    }

    private func setupTabViewController() {
        guard let window = window else { return }

        let tabVC = NSTabViewController()
        tabVC.tabStyle = .toolbar  // macOS-style tabs in toolbar
        tabVC.canPropagateSelectedChildViewControllerTitle = true

        self.tabViewController = tabVC

        // Set as window's content view controller
        window.contentViewController = tabVC

        // Create initial tab
        createNewTab(title: "Terminal")
    }

    // MARK: - Tab Creation

    /// Create a new tab
    @discardableResult
    func createNewTab(title: String = "Terminal", workingDirectory: String? = nil) -> TerminalTab {
        guard let tabViewController = tabViewController else {
            fatalError("TabViewController not initialized")
        }

        // Create terminal view controller
        let terminalVC = TerminalViewController()

        // Create tab item
        let tabViewItem = NSTabViewItem(viewController: terminalVC)
        tabViewItem.label = title

        // Create tab wrapper
        let tab = TerminalTab(
            tabViewItem: tabViewItem,
            terminalViewController: terminalVC,
            title: title
        )

        tabs.append(tab)

        // Add to tab view controller
        tabViewController.addTabViewItem(tabViewItem)

        // Select new tab
        selectTab(tab)

        // Set working directory if provided
        if let workDir = workingDirectory {
            // TODO: Send 'cd' command to terminal
        }

        return tab
    }

    // MARK: - Tab Management

    /// Close a specific tab
    func closeTab(_ tab: TerminalTab) {
        guard let index = tabs.firstIndex(where: { $0.id == tab.id }) else { return }

        tabs.remove(at: index)

        if let tabViewController = tabViewController,
           let tabViewItem = tab.tabViewItem {
            tabViewController.removeTabViewItem(tabViewItem)
        }

        // Close window if no tabs remain
        if tabs.isEmpty {
            window?.close()
        }
    }

    /// Close current tab
    func closeCurrentTab() {
        if let current = currentTab {
            closeTab(current)
        }
    }

    /// Select a specific tab
    func selectTab(_ tab: TerminalTab) {
        guard let tabViewController = tabViewController,
              let tabViewItem = tab.tabViewItem else { return }

        // Mark all as unselected
        tabs.forEach { $0.isSelected = false }

        // Select the tab
        tab.isSelected = true
        tabViewController.selectedTabViewItemIndex = tabViewController.tabViewItems.firstIndex(of: tabViewItem) ?? 0
    }

    /// Select tab by index
    func selectTab(at index: Int) {
        guard index >= 0 && index < tabs.count else { return }
        selectTab(tabs[index])
    }

    /// Select next tab
    func selectNextTab() {
        guard let current = currentTab,
              let currentIndex = tabs.firstIndex(where: { $0.id == current.id }) else { return }

        let nextIndex = (currentIndex + 1) % tabs.count
        selectTab(at: nextIndex)
    }

    /// Select previous tab
    func selectPreviousTab() {
        guard let current = currentTab,
              let currentIndex = tabs.firstIndex(where: { $0.id == current.id }) else { return }

        let prevIndex = currentIndex == 0 ? tabs.count - 1 : currentIndex - 1
        selectTab(at: prevIndex)
    }

    // MARK: - Tab Reordering

    /// Move tab to new index
    func moveTab(from sourceIndex: Int, to destinationIndex: Int) {
        guard sourceIndex >= 0 && sourceIndex < tabs.count &&
              destinationIndex >= 0 && destinationIndex < tabs.count else { return }

        let tab = tabs.remove(at: sourceIndex)
        tabs.insert(tab, at: destinationIndex)

        // Update tab view controller
        if let tabViewController = tabViewController,
           let tabViewItem = tab.tabViewItem {
            tabViewController.removeTabViewItem(tabViewItem)
            tabViewController.insertTabViewItem(tabViewItem, at: destinationIndex)
        }
    }

    // MARK: - Tab Information

    /// Get all tab titles
    func getTabTitles() -> [String] {
        return tabs.map { $0.title }
    }

    /// Update tab title
    func updateTabTitle(_ title: String, for tab: TerminalTab) {
        tab.title = title
        tab.tabViewItem?.label = title
    }

    /// Get tab by index
    func getTab(at index: Int) -> TerminalTab? {
        guard index >= 0 && index < tabs.count else { return nil }
        return tabs[index]
    }
}

// MARK: - TerminalTab

/// Represents a single terminal tab
class TerminalTab {
    let id = UUID()
    weak var tabViewItem: NSTabViewItem?
    weak var terminalViewController: TerminalViewController?
    var title: String
    var isSelected: Bool = false

    // Tab state
    var workingDirectory: String = "~"
    var hasActivity: Bool = false     // For tab activity indicators
    var hasAlert: Bool = false        // For tab alerts (bell)

    init(tabViewItem: NSTabViewItem, terminalViewController: TerminalViewController, title: String) {
        self.tabViewItem = tabViewItem
        self.terminalViewController = terminalViewController
        self.title = title
    }
}

// MARK: - Keyboard Shortcuts

extension TabManager {
    /// Handle keyboard shortcuts for tab management
    func handleKeyboardShortcut(_ event: NSEvent) -> Bool {
        guard let characters = event.charactersIgnoringModifiers else { return false }

        // Cmd+T: New tab
        if event.modifierFlags.contains(.command) && characters == "t" {
            createNewTab()
            return true
        }

        // Cmd+W: Close tab
        if event.modifierFlags.contains(.command) && characters == "w" {
            closeCurrentTab()
            return true
        }

        // Cmd+Shift+[: Previous tab
        if event.modifierFlags.contains([.command, .shift]) && characters == "[" {
            selectPreviousTab()
            return true
        }

        // Cmd+Shift+]: Next tab
        if event.modifierFlags.contains([.command, .shift]) && characters == "]" {
            selectNextTab()
            return true
        }

        // Cmd+1 through Cmd+9: Select specific tab
        if event.modifierFlags.contains(.command) {
            if let digit = Int(characters), digit >= 1 && digit <= 9 {
                selectTab(at: digit - 1)
                return true
            }
        }

        return false
    }
}
