import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let model = AppModel()
    private var floatingPanelController: FloatingPanelController?
    private var settingsWindowController: SettingsWindowController?
    private var statusBarController: StatusBarController?
    private var notificationTokens: [NSObjectProtocol] = []
    private var menuActivityTokens: [ObjectIdentifier: UUID] = [:]

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        applyAppearance()
        model.onAppearanceNeedsUpdate = { [weak self] in
            self?.applyAppearance()
        }
        installMenuActivityTracking()

        let settingsWindowController = SettingsWindowController(model: model)
        self.settingsWindowController = settingsWindowController

        model.onRequestSettings = { [weak settingsWindowController] in
            settingsWindowController?.show()
        }

        floatingPanelController = FloatingPanelController(model: model)
        statusBarController = StatusBarController(model: model)

        model.restoreFolderAndStart()
        if model.watchedFolder == nil {
            settingsWindowController.show()
        }
    }

    private func applyAppearance() {
        NSApp.appearance = model.appearanceMode.appKitAppearance
    }

    private func installMenuActivityTracking() {
        let center = NotificationCenter.default
        notificationTokens.append(
            center.addObserver(
                forName: NSMenu.didBeginTrackingNotification,
                object: nil,
                queue: .main
            ) { [weak self] notification in
                MainActor.assumeIsolated {
                    self?.menuDidBeginTracking(notification)
                }
            }
        )
        notificationTokens.append(
            center.addObserver(
                forName: NSMenu.didEndTrackingNotification,
                object: nil,
                queue: .main
            ) { [weak self] notification in
                MainActor.assumeIsolated {
                    self?.menuDidEndTracking(notification)
                }
            }
        )
    }

    private func menuDidBeginTracking(_ notification: Notification) {
        guard let menu = notification.object as? NSMenu else { return }
        let identifier = ObjectIdentifier(menu)
        guard menuActivityTokens[identifier] == nil else { return }
        menuActivityTokens[identifier] = model.beginActivity()
    }

    private func menuDidEndTracking(_ notification: Notification) {
        guard let menu = notification.object as? NSMenu,
              let token = menuActivityTokens.removeValue(
                forKey: ObjectIdentifier(menu)
              ) else {
            return
        }
        model.endActivity(token)
    }

    func applicationWillTerminate(_ notification: Notification) {
        for token in notificationTokens {
            NotificationCenter.default.removeObserver(token)
        }
        notificationTokens.removeAll()
        menuActivityTokens.removeAll()
        model.onAppearanceNeedsUpdate = nil
        model.shutdown()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        true
    }
}
