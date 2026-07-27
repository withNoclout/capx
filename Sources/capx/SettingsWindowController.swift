import AppKit
import SwiftUI

@MainActor
final class SettingsWindowController: NSWindowController, NSWindowDelegate {
    private let model: AppModel
    private var activityToken: UUID?

    init(model: AppModel) {
        self.model = model

        let hostingController = NSHostingController(rootView: SettingsView(model: model))
        let window = NSWindow(contentViewController: hostingController)
        window.title = "CapX Settings"
        window.styleMask = [.titled, .closable, .miniaturizable]
        window.isReleasedWhenClosed = false
        window.setContentSize(NSSize(width: 520, height: 580))
        window.contentMinSize = NSSize(width: 520, height: 580)
        window.contentMaxSize = NSSize(width: 520, height: 580)
        window.center()
        window.setFrameAutosaveName("com.withnoclout.capx.settings")

        super.init(window: window)
        window.delegate = self
    }

    required init?(coder: NSCoder) {
        nil
    }

    func show() {
        guard let window else { return }
        model.recordActivity()
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }

    func windowDidBecomeKey(_ notification: Notification) {
        guard activityToken == nil else { return }
        activityToken = model.beginActivity()
    }

    func windowDidResignKey(_ notification: Notification) {
        endWindowActivity()
    }

    func windowWillClose(_ notification: Notification) {
        endWindowActivity()
    }

    private func endWindowActivity() {
        guard let activityToken else { return }
        self.activityToken = nil
        model.endActivity(activityToken)
    }
}
