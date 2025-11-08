import Cocoa

/// Manages split panes within a terminal tab
class SplitPaneManager {
    // MARK: - Types

    enum SplitDirection {
        case horizontal  // Split left/right
        case vertical    // Split top/bottom
    }

    // MARK: - Properties

    private(set) var rootPane: Pane
    private(set) var activePane: Pane

    var allPanes: [Pane] {
        return collectPanes(from: rootPane)
    }

    // MARK: - Initialization

    init(initialViewController: TerminalViewController) {
        let pane = Pane(terminalViewController: initialViewController)
        self.rootPane = pane
        self.activePane = pane
    }

    // MARK: - Split Operations

    /// Split the active pane
    @discardableResult
    func splitActivePane(direction: SplitDirection) -> Pane {
        return split(pane: activePane, direction: direction)
    }

    /// Split a specific pane
    @discardableResult
    func split(pane: Pane, direction: SplitDirection) -> Pane {
        // Create new terminal for the new pane
        let newTerminalVC = TerminalViewController()
        let newPane = Pane(terminalViewController: newTerminalVC)

        // Create split view
        let splitView = NSSplitView()
        splitView.dividerStyle = .thin
        splitView.isVertical = (direction == .horizontal)

        // Get the parent of the pane being split
        if pane === rootPane {
            // Splitting the root pane
            rootPane = Pane(splitView: splitView, left: pane, right: newPane, direction: direction)
            return newPane
        } else {
            // Find parent and replace the pane with a split
            if let parent = findParent(of: pane, in: rootPane) {
                let newSplitPane = Pane(splitView: splitView, left: pane, right: newPane, direction: direction)

                if parent.leftChild === pane {
                    parent.leftChild = newSplitPane
                } else if parent.rightChild === pane {
                    parent.rightChild = newSplitPane
                }

                newSplitPane.parent = parent
                pane.parent = newSplitPane
                newPane.parent = newSplitPane

                return newPane
            }
        }

        return newPane
    }

    // MARK: - Pane Management

    /// Close a pane
    func closePane(_ pane: Pane) {
        guard pane !== rootPane else {
            // Can't close root pane if it's the only one
            if rootPane.isLeaf {
                return
            }
            // If root is a split, promote one child
            if let left = rootPane.leftChild {
                rootPane = left
                rootPane.parent = nil
                return
            }
            return
        }

        guard let parent = pane.parent else { return }

        // Get sibling
        let sibling = (parent.leftChild === pane) ? parent.rightChild : parent.leftChild

        guard let sibling = sibling else { return }

        // Replace parent with sibling
        if let grandparent = parent.parent {
            if grandparent.leftChild === parent {
                grandparent.leftChild = sibling
            } else if grandparent.rightChild === parent {
                grandparent.rightChild = sibling
            }
            sibling.parent = grandparent
        } else {
            // Parent was root
            rootPane = sibling
            sibling.parent = nil
        }
    }

    /// Close active pane
    func closeActivePane() {
        let nextActive = findNextPaneToActivate(after: activePane)
        closePane(activePane)
        if let next = nextActive {
            setActivePane(next)
        }
    }

    /// Set active pane
    func setActivePane(_ pane: Pane) {
        allPanes.forEach { $0.isActive = false }
        pane.isActive = true
        activePane = pane
    }

    // MARK: - Navigation

    /// Navigate to next pane
    func selectNextPane() {
        let panes = allPanes
        guard let currentIndex = panes.firstIndex(where: { $0 === activePane }) else { return }

        let nextIndex = (currentIndex + 1) % panes.count
        setActivePane(panes[nextIndex])
    }

    /// Navigate to previous pane
    func selectPreviousPane() {
        let panes = allPanes
        guard let currentIndex = panes.firstIndex(where: { $0 === activePane }) else { return }

        let prevIndex = currentIndex == 0 ? panes.count - 1 : currentIndex - 1
        setActivePane(panes[prevIndex])
    }

    /// Navigate in direction
    func navigatePane(direction: NavigationDirection) {
        // TODO: Implement directional navigation
        // This would find the pane in the specified direction from the active pane
    }

    enum NavigationDirection {
        case up, down, left, right
    }

    // MARK: - Helper Methods

    private func collectPanes(from pane: Pane) -> [Pane] {
        if pane.isLeaf {
            return [pane]
        } else {
            var panes: [Pane] = []
            if let left = pane.leftChild {
                panes.append(contentsOf: collectPanes(from: left))
            }
            if let right = pane.rightChild {
                panes.append(contentsOf: collectPanes(from: right))
            }
            return panes
        }
    }

    private func findParent(of pane: Pane, in tree: Pane) -> Pane? {
        if tree.leftChild === pane || tree.rightChild === pane {
            return tree
        }

        if let left = tree.leftChild, let found = findParent(of: pane, in: left) {
            return found
        }

        if let right = tree.rightChild, let found = findParent(of: pane, in: right) {
            return found
        }

        return nil
    }

    private func findNextPaneToActivate(after pane: Pane) -> Pane? {
        let panes = allPanes.filter { $0 !== pane }
        return panes.first
    }

    // MARK: - View Construction

    /// Build the split view hierarchy
    func buildViewHierarchy() -> NSView? {
        return buildView(for: rootPane)
    }

    private func buildView(for pane: Pane) -> NSView? {
        if pane.isLeaf {
            return pane.terminalViewController?.view
        } else if let splitView = pane.splitView {
            // Recursively build child views
            if let leftView = pane.leftChild.flatMap({ buildView(for: $0) }),
               let rightView = pane.rightChild.flatMap({ buildView(for: $0) }) {
                splitView.addArrangedSubview(leftView)
                splitView.addArrangedSubview(rightView)
                return splitView
            }
        }

        return nil
    }
}

// MARK: - Pane

/// Represents a pane in the split hierarchy
class Pane {
    let id = UUID()

    // Leaf pane (actual terminal)
    weak var terminalViewController: TerminalViewController?

    // Split pane (container)
    var splitView: NSSplitView?
    var direction: SplitPaneManager.SplitDirection?
    var leftChild: Pane?
    var rightChild: Pane?

    weak var parent: Pane?

    var isActive: Bool = false

    var isLeaf: Bool {
        return terminalViewController != nil
    }

    // Leaf pane initializer
    init(terminalViewController: TerminalViewController) {
        self.terminalViewController = terminalViewController
    }

    // Split pane initializer
    init(splitView: NSSplitView, left: Pane, right: Pane, direction: SplitPaneManager.SplitDirection) {
        self.splitView = splitView
        self.leftChild = left
        self.rightChild = right
        self.direction = direction

        left.parent = self
        right.parent = self
    }
}

// MARK: - Keyboard Shortcuts

extension SplitPaneManager {
    func handleKeyboardShortcut(_ event: NSEvent) -> Bool {
        guard let characters = event.charactersIgnoringModifiers else { return false }

        // Cmd+D: Split horizontally
        if event.modifierFlags.contains(.command) && characters == "d" {
            splitActivePane(direction: .horizontal)
            return true
        }

        // Cmd+Shift+D: Split vertically
        if event.modifierFlags.contains([.command, .shift]) && characters == "D" {
            splitActivePane(direction: .vertical)
            return true
        }

        // Cmd+Shift+W: Close pane
        if event.modifierFlags.contains([.command, .shift]) && characters == "W" {
            closeActivePane()
            return true
        }

        // Cmd+[: Previous pane
        if event.modifierFlags.contains(.command) && event.keyCode == 33 { // [ key
            selectPreviousPane()
            return true
        }

        // Cmd+]: Next pane
        if event.modifierFlags.contains(.command) && event.keyCode == 30 { // ] key
            selectNextPane()
            return true
        }

        return false
    }
}
