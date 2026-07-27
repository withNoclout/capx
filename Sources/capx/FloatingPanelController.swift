import AppKit
import CoreGraphics
import SwiftUI

final class SidebarPanel: NSPanel {
  override var canBecomeKey: Bool { true }
  override var canBecomeMain: Bool { false }
}

@MainActor
final class FloatingPanelController {
  static let width: CGFloat = 380
  private static let mouseTrackingInterval: TimeInterval = 0.15

  private let model: AppModel
  private let panel: SidebarPanel
  private var notificationTokens: [NSObjectProtocol] = []
  private var mouseTrackingTimer: Timer?
  private var targetDisplayID: CGDirectDisplayID?
  private var targetScreenFrame: NSRect?

  private var isAutomaticallyHidden = false

  init(model: AppModel) {
    self.model = model

    panel = SidebarPanel(
      contentRect: NSRect(x: 0, y: 0, width: Self.width, height: 420),
      styleMask: [.borderless, .nonactivatingPanel, .utilityWindow],
      backing: .buffered,
      defer: false
    )

    panel.contentViewController = NSHostingController(rootView: SidebarView(model: model))
    panel.backgroundColor = .clear
    panel.isOpaque = false
    panel.hasShadow = true
    panel.level = .floating
    panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
    panel.hidesOnDeactivate = false
    panel.isFloatingPanel = true
    panel.becomesKeyOnlyIfNeeded = true
    panel.isReleasedWhenClosed = false
    panel.animationBehavior = .utilityWindow
    panel.setAccessibilityTitle("CapX screenshot sidebar")

    model.onPanelNeedsLayout = { [weak self] in
      self?.updatePanel(animated: true)
    }

    model.onPanelAutoHiddenChange = { [weak self] hidden in
      guard let self else { return }
      self.isAutomaticallyHidden = hidden
      self.updatePanel(animated: false)
    }

    let center = NotificationCenter.default
    notificationTokens.append(
      center.addObserver(
        forName: NSApplication.didChangeScreenParametersNotification,
        object: nil,
        queue: .main
      ) { [weak self] _ in
        Task { @MainActor in
          self?.updatePanel(animated: false)
        }
      }
    )

    updatePanel(animated: false)
  }

  func updatePanel(animated: Bool) {
    let shouldShow = model.isSidebarVisible
      && !model.captures.isEmpty
      && !isAutomaticallyHidden
    setMouseTrackingEnabled(
      shouldShow && model.displayPreference == .followMouse
    )

    guard shouldShow else {
      panel.orderOut(nil)
      return
    }

    guard let screen = targetScreen() else { return }
    let visibleFrame = screen.visibleFrame
    let availableHeight = max(240, visibleFrame.height - 24)
    let rowCount = max(1, (model.captures.count + 1) / 2)
    let desiredHeight = 258 + CGFloat(rowCount) * 150
    let height = min(max(desiredHeight, 420), availableHeight)
    let x: CGFloat

    switch model.side {
    case .left:
      x = visibleFrame.minX + 12
    case .right:
      x = visibleFrame.maxX - Self.width - 12
    }

    let frame = NSRect(
      x: x,
      y: visibleFrame.maxY - height - 12,
      width: Self.width,
      height: height
    )

    let isChangingDisplays = panel.isVisible
      && panel.screen.map { !isSameDisplay($0, screen) } == true
    panel.setFrame(
      frame,
      display: true,
      animate: animated && panel.isVisible && !isChangingDisplays
    )
    targetDisplayID = screen.capxDisplayID
    targetScreenFrame = screen.frame
    panel.orderFrontRegardless()
  }

  private func targetScreen() -> NSScreen? {
    let screens = NSScreen.screens

    switch model.displayPreference {
    case .followMouse:
      return screenContainingMouse(in: screens)
        ?? panel.screen
        ?? mainDisplay(in: screens)
    case .mainDisplay:
      return mainDisplay(in: screens)
    case let .display(identifier):
      return screens.first { $0.capxDisplayIdentifier == identifier }
        ?? mainDisplay(in: screens)
    }
  }

  private func screenContainingMouse(in screens: [NSScreen]) -> NSScreen? {
    let mouseLocation = NSEvent.mouseLocation
    return screens.first {
      NSMouseInRect(mouseLocation, $0.frame, false)
    }
  }

  private func mainDisplay(in screens: [NSScreen]) -> NSScreen? {
    let mainDisplayID = CGMainDisplayID()
    return screens.first { $0.capxDisplayID == mainDisplayID }
      ?? NSScreen.main
      ?? screens.first
  }

  private func setMouseTrackingEnabled(_ enabled: Bool) {
    guard enabled else {
      mouseTrackingTimer?.invalidate()
      mouseTrackingTimer = nil
      return
    }
    guard mouseTrackingTimer == nil else { return }

    let timer = Timer(
      timeInterval: Self.mouseTrackingInterval,
      repeats: true
    ) { [weak self] _ in
      MainActor.assumeIsolated {
        self?.movePanelToMouseScreenIfNeeded()
      }
    }
    mouseTrackingTimer = timer
    RunLoop.main.add(timer, forMode: .common)
  }

  private func movePanelToMouseScreenIfNeeded() {
    guard model.displayPreference == .followMouse,
          let screen = screenContainingMouse(in: NSScreen.screens),
          !isCurrentTarget(screen) else {
      return
    }

    updatePanel(animated: false)
  }

  private func isCurrentTarget(_ screen: NSScreen) -> Bool {
    if let targetDisplayID, let displayID = screen.capxDisplayID {
      return targetDisplayID == displayID
    }
    return targetScreenFrame == screen.frame
  }

  private func isSameDisplay(_ lhs: NSScreen, _ rhs: NSScreen) -> Bool {
    if let lhsID = lhs.capxDisplayID, let rhsID = rhs.capxDisplayID {
      return lhsID == rhsID
    }
    return lhs.frame == rhs.frame
  }

  deinit {
    mouseTrackingTimer?.invalidate()
    for token in notificationTokens {
      NotificationCenter.default.removeObserver(token)
    }
  }
}
