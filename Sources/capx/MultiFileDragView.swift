import AppKit
import SwiftUI

@MainActor
struct SingleFileDragView: NSViewRepresentable {
  let url: URL
  let onOpen: () -> Void
  let onDragStarted: () -> Void
  let onDragEnded: () -> Void

  func makeNSView(context: Context) -> SingleFileDragSourceView {
    let view = SingleFileDragSourceView()
    update(view)
    return view
  }

  func updateNSView(_ nsView: SingleFileDragSourceView, context: Context) {
    update(nsView)
  }

  private func update(_ view: SingleFileDragSourceView) {
    view.url = url
    view.onOpen = onOpen
    view.onDragStarted = onDragStarted
    view.onDragEnded = onDragEnded
  }
}

@MainActor
final class SingleFileDragSourceView: NSView, NSDraggingSource {
  var url: URL?
  var onOpen: () -> Void = {}
  var onDragStarted: () -> Void = {}
  var onDragEnded: () -> Void = {}

  private var hasStartedDragging = false

  override init(frame frameRect: NSRect) {
    super.init(frame: frameRect)
    setAccessibilityElement(false)
  }

  required init?(coder: NSCoder) {
    super.init(coder: coder)
    setAccessibilityElement(false)
  }

  override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
    true
  }

  override func resetCursorRects() {
    addCursorRect(bounds, cursor: url == nil ? .arrow : .openHand)
  }

  override func mouseDown(with event: NSEvent) {
    hasStartedDragging = false
  }

  override func mouseDragged(with event: NSEvent) {
    guard !hasStartedDragging, let url else { return }
    hasStartedDragging = true

    let item = NSDraggingItem(pasteboardWriter: url as NSURL)
    let icon = NSWorkspace.shared.icon(forFile: url.path)
    icon.size = NSSize(width: 44, height: 44)
    item.setDraggingFrame(
      NSRect(
        x: bounds.midX - 22,
        y: bounds.midY - 22,
        width: 44,
        height: 44
      ),
      contents: icon
    )

    onDragStarted()
    beginDraggingSession(with: [item], event: event, source: self)
  }

  override func mouseUp(with event: NSEvent) {
    if !hasStartedDragging {
      onOpen()
    }
  }

  override func rightMouseDown(with event: NSEvent) {
    nextResponder?.rightMouseDown(with: event)
  }

  func draggingSession(
    _ session: NSDraggingSession,
    sourceOperationMaskFor context: NSDraggingContext
  ) -> NSDragOperation {
    .copy
  }

  func draggingSession(
    _ session: NSDraggingSession,
    endedAt screenPoint: NSPoint,
    operation: NSDragOperation
  ) {
    hasStartedDragging = false
    onDragEnded()
  }

  func ignoreModifierKeys(for session: NSDraggingSession) -> Bool {
    true
  }
}

@MainActor
struct MultiFileDragButton: NSViewRepresentable {
  let urls: [URL]
  let title: String
  let isProminent: Bool
  let accentColor: NSColor
  let accentForegroundColor: NSColor
  let foregroundColor: NSColor
  let onDragStarted: () -> Void
  let onDragEnded: () -> Void

  init(
    urls: [URL],
    title: String = "Drag all",
    isProminent: Bool = false,
    accentColor: NSColor = .controlAccentColor,
    accentForegroundColor: NSColor = .white,
    foregroundColor: NSColor = .labelColor,
    onDragStarted: @escaping () -> Void = {},
    onDragEnded: @escaping () -> Void = {}
  ) {
    self.urls = urls
    self.title = title
    self.isProminent = isProminent
    self.accentColor = accentColor
    self.accentForegroundColor = accentForegroundColor
    self.foregroundColor = foregroundColor
    self.onDragStarted = onDragStarted
    self.onDragEnded = onDragEnded
  }

  func makeNSView(context: Context) -> MultiFileDragView {
    let view = MultiFileDragView()
    view.urls = urls
    view.title = title
    view.isProminent = isProminent
    view.accentColor = accentColor
    view.accentForegroundColor = accentForegroundColor
    view.foregroundColor = foregroundColor
    view.onDragStarted = onDragStarted
    view.onDragEnded = onDragEnded
    return view
  }

  func updateNSView(_ nsView: MultiFileDragView, context: Context) {
    nsView.urls = urls
    nsView.title = title
    nsView.isProminent = isProminent
    nsView.accentColor = accentColor
    nsView.accentForegroundColor = accentForegroundColor
    nsView.foregroundColor = foregroundColor
    nsView.onDragStarted = onDragStarted
    nsView.onDragEnded = onDragEnded
  }
}

@MainActor
final class MultiFileDragView: NSView, NSDraggingSource {
  var onDragStarted: () -> Void = {}
  var onDragEnded: () -> Void = {}
  var title = "Drag all" {
    didSet {
      needsDisplay = true
      invalidateIntrinsicContentSize()
      updateAccessibilityMetadata()
    }
  }
  var isProminent = false {
    didSet {
      needsDisplay = true
      invalidateIntrinsicContentSize()
    }
  }
  var accentColor = NSColor.controlAccentColor {
    didSet { needsDisplay = true }
  }
  var accentForegroundColor = NSColor.white {
    didSet { needsDisplay = true }
  }
  var foregroundColor = NSColor.labelColor {
    didSet { needsDisplay = true }
  }
  var urls: [URL] = [] {
    didSet {
      needsDisplay = true
      discardCursorRects()
      setAccessibilityValue("\(urls.count) screenshots")
    }
  }

  private var isHovering = false
  private var hasStartedDragging = false
  private var hasPushedDragCursor = false
  private var trackingAreaReference: NSTrackingArea?

  override init(frame frameRect: NSRect) {
    super.init(frame: frameRect)
    setAccessibilityElement(true)
    setAccessibilityRole(.button)
    updateAccessibilityMetadata()
  }

  required init?(coder: NSCoder) {
    super.init(coder: coder)
    setAccessibilityElement(true)
    setAccessibilityRole(.button)
    updateAccessibilityMetadata()
  }

  private func updateAccessibilityMetadata() {
    let isSelectedDrag = title == "Drag"
    setAccessibilityLabel(isSelectedDrag ? "Drag selected screenshots" : title)
    setAccessibilityHelp(
      isSelectedDrag
        ? "Drag selected screenshots to another app."
        : "Drag every screenshot to another app."
    )
  }

  override var intrinsicContentSize: NSSize {
    let font = NSFont.systemFont(
      ofSize: isProminent ? 13 : 11,
      weight: isProminent ? .semibold : .medium
    )
    let textWidth = ceil((title as NSString).size(withAttributes: [.font: font]).width)
    return NSSize(
      width: max(isProminent ? 220 : 76, textWidth + (isProminent ? 52 : 40)),
      height: isProminent ? 42 : 32
    )
  }

  override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
    true
  }

  override func updateTrackingAreas() {
    if let trackingAreaReference {
      removeTrackingArea(trackingAreaReference)
    }

    let trackingArea = NSTrackingArea(
      rect: bounds,
      options: [.activeAlways, .mouseEnteredAndExited, .inVisibleRect],
      owner: self,
      userInfo: nil
    )
    addTrackingArea(trackingArea)
    trackingAreaReference = trackingArea
    super.updateTrackingAreas()
  }

  override func resetCursorRects() {
    addCursorRect(bounds, cursor: urls.isEmpty ? .arrow : .openHand)
  }

  override func mouseEntered(with event: NSEvent) {
    isHovering = true
    needsDisplay = true
  }

  override func mouseExited(with event: NSEvent) {
    isHovering = false
    needsDisplay = true
  }

  override func mouseDown(with event: NSEvent) {
    hasStartedDragging = false
  }

  override func mouseDragged(with event: NSEvent) {
    guard !hasStartedDragging, !urls.isEmpty else { return }
    hasStartedDragging = true

    let items = Self.draggingItems(for: urls, in: bounds)
    guard !items.isEmpty else { return }

    NSCursor.closedHand.push()
    onDragStarted()
    hasPushedDragCursor = true
    beginDraggingSession(with: items, event: event, source: self)
  }

  override func mouseUp(with event: NSEvent) {
    onDragEnded()
    hasStartedDragging = false
  }

  func draggingSession(
    _ session: NSDraggingSession,
    sourceOperationMaskFor context: NSDraggingContext
  ) -> NSDragOperation {
    .copy
  }

  func draggingSession(
    _ session: NSDraggingSession,
    endedAt screenPoint: NSPoint,
    operation: NSDragOperation
  ) {
    if hasPushedDragCursor {
      NSCursor.pop()
      hasPushedDragCursor = false
    }
    hasStartedDragging = false
    onDragEnded()
  }

  func ignoreModifierKeys(for session: NSDraggingSession) -> Bool {
    true
  }

  override func draw(_ dirtyRect: NSRect) {
    super.draw(dirtyRect)

    let path = NSBezierPath(
      roundedRect: bounds.insetBy(dx: 0.5, dy: 0.5),
      xRadius: 8,
      yRadius: 8
    )
    let foreground: NSColor
    let increaseContrast = NSWorkspace.shared.accessibilityDisplayShouldIncreaseContrast
    if isProminent {
      accentColor.withAlphaComponent(isHovering ? 0.88 : 1).setFill()
      path.fill()
      foreground = accentForegroundColor
    } else {
      let background =
        isHovering
        ? accentColor.withAlphaComponent(increaseContrast ? 0.28 : 0.18)
        : foregroundColor.withAlphaComponent(increaseContrast ? 0.12 : 0.07)
      background.setFill()
      path.fill()
      (isHovering ? accentColor : foregroundColor)
        .withAlphaComponent(increaseContrast ? 0.75 : 0.35)
        .setStroke()
      path.lineWidth = 1
      path.stroke()
      foreground = foregroundColor
    }

    let font = NSFont.systemFont(
      ofSize: isProminent ? 13 : 11,
      weight: isProminent ? .semibold : .medium
    )
    let attributes: [NSAttributedString.Key: Any] = [
      .font: font,
      .foregroundColor: foreground,
    ]
    let attributedTitle = NSAttributedString(string: title, attributes: attributes)
    let titleSize = attributedTitle.size()
    let symbolSize: CGFloat = isProminent ? 16 : 13
    let spacing: CGFloat = isProminent ? 8 : 6
    let contentWidth = symbolSize + spacing + titleSize.width
    let startX = bounds.midX - contentWidth / 2
    let configuration = NSImage.SymbolConfiguration(
      pointSize: symbolSize,
      weight: .semibold
    ).applying(NSImage.SymbolConfiguration(paletteColors: [foreground]))
    if let image = NSImage(
      systemSymbolName: "square.stack.3d.up",
      accessibilityDescription: nil
    )?.withSymbolConfiguration(configuration) {
      image.draw(
        in: NSRect(
          x: startX,
          y: bounds.midY - symbolSize / 2,
          width: symbolSize,
          height: symbolSize
        ),
        from: .zero,
        operation: .sourceOver,
        fraction: 1
      )
    }

    attributedTitle.draw(
      at: NSPoint(
        x: startX + symbolSize + spacing,
        y: bounds.midY - titleSize.height / 2
      )
    )
  }

  static func pasteboardWriters(for urls: [URL]) -> [NSPasteboardWriting] {
    urls.map { $0 as NSURL }
  }

  private static func draggingItems(for urls: [URL], in bounds: NSRect) -> [NSDraggingItem] {
    zip(urls, pasteboardWriters(for: urls)).enumerated().map { index, pair in
      let (url, writer) = pair
      let item = NSDraggingItem(pasteboardWriter: writer)
      let icon = NSWorkspace.shared.icon(forFile: url.path)
      icon.size = NSSize(width: 44, height: 44)

      let offset = CGFloat(min(index, 4)) * 4
      item.setDraggingFrame(
        NSRect(
          x: bounds.midX - 22 + offset,
          y: bounds.midY - 22 - offset,
          width: 44,
          height: 44
        ),
        contents: icon
      )
      return item
    }
  }
}
