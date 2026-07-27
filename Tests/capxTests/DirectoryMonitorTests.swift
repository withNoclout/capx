import AppKit
import Foundation
import XCTest

@testable import capx

final class DirectoryMonitorTests: XCTestCase {
  private let pngData = Data(
    base64Encoded:
      "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII="
  )!

  func testReportsOnlyImagesAddedAfterMonitoringStarts() throws {
    let folder = try makeTemporaryDirectory()
    defer { try? FileManager.default.removeItem(at: folder) }

    let baseline = folder.appendingPathComponent("baseline.png")
    try pngData.write(to: baseline)

    let monitor = DirectoryMonitor(folderURL: folder)
    defer { monitor.stop() }

    let detected = expectation(description: "new image detected")
    let lock = NSLock()
    var reportedNames: [String] = []

    try monitor.start { urls in
      lock.lock()
      reportedNames.append(contentsOf: urls.map(\.lastPathComponent))
      let foundNewImage = reportedNames.contains("new.png")
      lock.unlock()

      if foundNewImage {
        detected.fulfill()
      }
    }

    try Data("not an image".utf8).write(
      to: folder.appendingPathComponent("notes.txt"),
      options: .atomic
    )
    try pngData.write(
      to: folder.appendingPathComponent("new.png"),
      options: .atomic
    )

    wait(for: [detected], timeout: 3)

    lock.lock()
    let result = reportedNames
    lock.unlock()

    XCTAssertEqual(result, ["new.png"])
  }

  func testThumbnailLoaderReadsACompleteImage() throws {
    let folder = try makeTemporaryDirectory()
    defer { try? FileManager.default.removeItem(at: folder) }

    let imageURL = folder.appendingPathComponent("capture.png")
    try pngData.write(to: imageURL)

    let loaded = expectation(description: "thumbnail loaded")
    ThumbnailLoader().load(imageURL) { capture in
      XCTAssertEqual(capture?.url, imageURL)
      XCTAssertNotNil(capture?.thumbnail)
      loaded.fulfill()
    }

    wait(for: [loaded], timeout: 3)
  }

  @MainActor
  func testDragAllCreatesOnePasteboardWriterPerScreenshot() {
    let urls = [
      URL(fileURLWithPath: "/tmp/first.png"),
      URL(fileURLWithPath: "/tmp/second.png"),
      URL(fileURLWithPath: "/tmp/third.png"),
    ]

    let writers = MultiFileDragView.pasteboardWriters(for: urls)
    let representedURLs = writers.compactMap { $0 as? NSURL }.map { $0 as URL }

    XCTAssertEqual(representedURLs, urls)
  }

  private func makeTemporaryDirectory() throws -> URL {
    let url = FileManager.default.temporaryDirectory
      .appendingPathComponent("capx-tests-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url
  }
}

final class SettingsTests: XCTestCase {
  private let pngData = Data(
    base64Encoded:
      "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII="
  )!

  @MainActor
  func testRecentScreenshotLimitAcceptsMoreThanFiveAndCapsAtTwenty() {
    let suiteName = "capx-tests-\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suiteName)!
    defer { defaults.removePersistentDomain(forName: suiteName) }
    defaults.set(8, forKey: "maxRecent")

    let model = AppModel(defaults: defaults)

    XCTAssertEqual(model.maxRecent, 8)

    model.maxRecent = 21

    XCTAssertEqual(model.maxRecent, 20)
    XCTAssertEqual(defaults.integer(forKey: "maxRecent"), 20)
  }

  @MainActor
  func testDisplaySelectionLoadsAndPersistsMainOrSpecificDisplay() {
    let suiteName = "capx-tests-\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suiteName)!
    defer { defaults.removePersistentDomain(forName: suiteName) }
    defaults.set("mainDisplay", forKey: "sidebarDisplay")

    let model = AppModel(defaults: defaults)

    XCTAssertEqual(model.displayPreference, .mainDisplay)

    model.displayPreference = .display("test-display-id")

    XCTAssertEqual(
      defaults.string(forKey: "sidebarDisplay"),
      "display:test-display-id"
    )
  }

  @MainActor
  func testCapxPalettesUseDistinctOwnedColors() {
    let light = CapxTheme.light.palette
    let dark = CapxTheme.dark.palette

    XCTAssertNotEqual(light.background, dark.background)
    XCTAssertNotEqual(light.foreground, dark.foreground)
    XCTAssertNotEqual(light.accent, dark.accent)
  }

  @MainActor
  func testAppearancePreferencesLoadPersistNotifyAndRemoveLegacyThemes() {
    let suiteName = "capx-tests-\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suiteName)!
    defer { defaults.removePersistentDomain(forName: suiteName) }
    defaults.set("dark", forKey: "appearanceMode")
    defaults.set("legacy-light-theme", forKey: "lightTheme")
    defaults.set("legacy-dark-theme", forKey: "darkTheme")

    let model = AppModel(defaults: defaults)
    XCTAssertEqual(model.appearanceMode, .dark)
    XCTAssertNil(defaults.object(forKey: "lightTheme"))
    XCTAssertNil(defaults.object(forKey: "darkTheme"))

    var appearanceUpdates = 0
    model.onAppearanceNeedsUpdate = {
      appearanceUpdates += 1
    }
    model.appearanceMode = .light

    XCTAssertEqual(appearanceUpdates, 1)
    XCTAssertEqual(defaults.string(forKey: "appearanceMode"), "light")

    let restored = AppModel(defaults: defaults)
    XCTAssertEqual(restored.appearanceMode, .light)
  }

  @MainActor
  func testCapxAppearancePalettesHaveReadableFlatColors() {
    let palettes = [
      ("CapX Light", CapxTheme.light.palette),
      ("CapX Dark", CapxTheme.dark.palette),
    ]

    for (name, palette) in palettes {
      XCTAssertNotEqual(palette.background, palette.foreground, name)
      XCTAssertNotEqual(palette.background, palette.accent, name)
      XCTAssertGreaterThanOrEqual(
        contrastRatio(palette.backgroundNSColor, palette.foregroundNSColor),
        4.5,
        name
      )
      XCTAssertGreaterThanOrEqual(
        contrastRatio(palette.accentNSColor, palette.accentForegroundNSColor),
        4.5,
        name
      )
    }
  }

  @MainActor
  func testTimeoutSettingsPersistAndClampToSupportedRanges() {
    let suiteName = "capx-tests-\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suiteName)!
    defer { defaults.removePersistentDomain(forName: suiteName) }

    let model = AppModel(defaults: defaults)

    model.autoHideSeconds = 601
    model.autoClearSeconds = 3_601

    XCTAssertEqual(model.autoHideSeconds, 600)
    XCTAssertEqual(model.autoClearSeconds, 3_600)
    XCTAssertEqual(defaults.integer(forKey: "autoHideSeconds"), 600)
    XCTAssertEqual(defaults.integer(forKey: "autoClearSeconds"), 3_600)

    let restored = AppModel(defaults: defaults)
    XCTAssertEqual(restored.autoHideSeconds, 600)
    XCTAssertEqual(restored.autoClearSeconds, 3_600)
  }

  @MainActor
  func testAutoHideKeepsCapturesAndSidebarEnabled() async throws {
    let suiteName = "capx-tests-\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suiteName)!
    let folder = try makeTemporaryDirectory()
    let model = AppModel(defaults: defaults)
    defer {
      model.onPanelAutoHiddenChange = nil
      model.shutdown()
      defaults.removePersistentDomain(forName: suiteName)
      try? FileManager.default.removeItem(at: folder)
    }

    model.autoHideSeconds = 1
    model.setFolder(folder)

    let hidden = expectation(description: "sidebar automatically hidden")
    model.onPanelAutoHiddenChange = { isHidden in
      if isHidden {
        hidden.fulfill()
      }
    }

    try pngData.write(
      to: folder.appendingPathComponent("auto-hide.png"),
      options: .atomic
    )

    await fulfillment(of: [hidden], timeout: 3)

    XCTAssertEqual(model.captures.count, 1)
    XCTAssertTrue(model.isSidebarVisible)
  }

  @MainActor
  func testManualTimerPausePreventsHideUntilResumed() async throws {
    let suiteName = "capx-tests-\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suiteName)!
    let folder = try makeTemporaryDirectory()
    let model = AppModel(defaults: defaults)
    defer {
      model.onPanelNeedsLayout = nil
      model.onPanelAutoHiddenChange = nil
      model.shutdown()
      defaults.removePersistentDomain(forName: suiteName)
      try? FileManager.default.removeItem(at: folder)
    }

    model.autoHideSeconds = 1
    model.setFolder(folder)

    let loaded = expectation(description: "screenshot loaded before timer pause")
    var didFulfillLoaded = false
    model.onPanelNeedsLayout = { [weak model] in
      guard !didFulfillLoaded, model?.captures.count == 1 else { return }
      didFulfillLoaded = true
      loaded.fulfill()
    }

    var didHide = false
    let hidden = expectation(description: "sidebar hidden after timer resume")
    model.onPanelAutoHiddenChange = { isHidden in
      guard isHidden else { return }
      didHide = true
      hidden.fulfill()
    }

    try pngData.write(
      to: folder.appendingPathComponent("manual-pause.png"),
      options: .atomic
    )
    await fulfillment(of: [loaded], timeout: 3)

    XCTAssertTrue(model.canPauseAutomaticTimers)
    XCTAssertTrue(model.isAutomaticCountdownActive)

    model.toggleAutomaticTimersPaused()

    XCTAssertTrue(model.areAutomaticTimersPaused)
    XCTAssertFalse(model.isAutomaticCountdownActive)
    XCTAssertEqual(model.autoHideRemainingSeconds, 1)

    try await Task<Never, Never>.sleep(nanoseconds: 1_300_000_000)
    XCTAssertFalse(didHide)

    model.toggleAutomaticTimersPaused()

    XCTAssertFalse(model.areAutomaticTimersPaused)
    XCTAssertTrue(model.isAutomaticCountdownActive)
    await fulfillment(of: [hidden], timeout: 2)
  }

  @MainActor
  func testAutoClearRemovesUnpinnedCapturesAndKeepsPinnedOnes() async throws {
    let suiteName = "capx-tests-\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suiteName)!
    let folder = try makeTemporaryDirectory()
    let model = AppModel(defaults: defaults)
    defer {
      model.onPanelNeedsLayout = nil
      model.shutdown()
      defaults.removePersistentDomain(forName: suiteName)
      try? FileManager.default.removeItem(at: folder)
    }

    model.autoClearSeconds = 1
    model.setFolder(folder)

    let loaded = expectation(description: "two screenshots loaded")
    var didFulfillLoaded = false
    model.onPanelNeedsLayout = { [weak model] in
      guard !didFulfillLoaded, model?.captures.count == 2 else { return }
      didFulfillLoaded = true
      loaded.fulfill()
    }

    try pngData.write(
      to: folder.appendingPathComponent("keep-pinned.png"),
      options: .atomic
    )
    try pngData.write(
      to: folder.appendingPathComponent("clear-recent.png"),
      options: .atomic
    )

    await fulfillment(of: [loaded], timeout: 3)
    model.togglePin(model.captures[0])

    try await Task<Never, Never>.sleep(nanoseconds: 1_300_000_000)

    XCTAssertEqual(model.captures.count, 1)
    XCTAssertTrue(model.captures[0].isPinned)
  }

  private func contrastRatio(_ lhs: NSColor, _ rhs: NSColor) -> CGFloat {
    let lighter = max(relativeLuminance(lhs), relativeLuminance(rhs))
    let darker = min(relativeLuminance(lhs), relativeLuminance(rhs))
    return (lighter + 0.05) / (darker + 0.05)
  }

  private func relativeLuminance(_ color: NSColor) -> CGFloat {
    guard let color = color.usingColorSpace(.sRGB) else { return 0 }
    let channels = [color.redComponent, color.greenComponent, color.blueComponent]
      .map { channel in
        channel <= 0.04045
          ? channel / 12.92
          : pow((channel + 0.055) / 1.055, 2.4)
      }
    return 0.2126 * channels[0] + 0.7152 * channels[1] + 0.0722 * channels[2]
  }

  private func makeTemporaryDirectory() throws -> URL {
    let url = FileManager.default.temporaryDirectory
      .appendingPathComponent("capx-settings-tests-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url
  }
}
