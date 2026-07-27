import AppKit

@MainActor
final class StatusBarController: NSObject, NSMenuDelegate {
    private let model: AppModel
    private let statusItem: NSStatusItem
    private let menu = NSMenu()

    init(model: AppModel) {
        self.model = model
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        super.init()

        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "rectangle.stack.fill", accessibilityDescription: "CapX")
            button.image?.isTemplate = true
            button.toolTip = "CapX"
        }

        menu.delegate = self
        statusItem.menu = menu
    }

    func menuWillOpen(_ menu: NSMenu) {
        rebuildMenu()
    }

    private func rebuildMenu() {
        menu.removeAllItems()

        addItem(
            model.isSidebarVisible ? "Hide Sidebar" : "Show Sidebar",
            action: #selector(toggleSidebar),
            keyEquivalent: "s"
        )
        addItem("Choose Screenshots Folder…", action: #selector(chooseFolder))

        let openFolder = addItem("Open Screenshots Folder", action: #selector(openFolder))
        openFolder.isEnabled = model.watchedFolder != nil

        let clear = addItem("Clear Recent", action: #selector(clearRecent))
        clear.isEnabled = model.captures.contains { !$0.isPinned }

        menu.addItem(.separator())

        let positionItem = NSMenuItem(title: "Sidebar Position", action: nil, keyEquivalent: "")
        let positionMenu = NSMenu()
        for side in SidebarSide.allCases {
            let item = NSMenuItem(title: side.title, action: #selector(setSide(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = side.rawValue
            item.state = model.side == side ? .on : .off
            positionMenu.addItem(item)
        }
        positionItem.submenu = positionMenu
        menu.addItem(positionItem)

        menu.addItem(.separator())
        addItem("Settings…", action: #selector(showSettings), keyEquivalent: ",")
        addItem("Quit CapX", action: #selector(quit), keyEquivalent: "q")
    }

    @discardableResult
    private func addItem(_ title: String, action: Selector, keyEquivalent: String = "") -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: keyEquivalent)
        item.target = self
        menu.addItem(item)
        return item
    }

    @objc private func toggleSidebar() {
        model.toggleSidebar()
    }

    @objc private func chooseFolder() {
        model.chooseFolder()
    }

    @objc private func openFolder() {
        model.openWatchedFolder()
    }

    @objc private func clearRecent() {
        model.clearRecent()
    }

    @objc private func setSide(_ sender: NSMenuItem) {
        guard let rawValue = sender.representedObject as? String,
              let side = SidebarSide(rawValue: rawValue) else {
            return
        }
        model.side = side
    }

    @objc private func showSettings() {
        model.requestSettings()
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}
