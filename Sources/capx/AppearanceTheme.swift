import AppKit
import SwiftUI

enum CapxAppearanceMode: String, CaseIterable, Identifiable {
  case system
  case light
  case dark

  var id: Self { self }
  var title: String { rawValue.capitalized }

  var appKitAppearance: NSAppearance? {
    switch self {
    case .system:
      return nil
    case .light:
      return NSAppearance(named: .aqua)
    case .dark:
      return NSAppearance(named: .darkAqua)
    }
  }
}

struct CapxTheme {
  static let light = CapxTheme(
    palette: CapxThemePalette(
      background: 0xF7F8FA,
      foreground: 0x1F252B,
      accent: 0x0B7471
    )
  )

  static let dark = CapxTheme(
    palette: CapxThemePalette(
      background: 0x15191D,
      foreground: 0xF4F7F8,
      accent: 0x36CFC3
    )
  )

  let palette: CapxThemePalette
}

struct CapxThemePalette {
  let background: UInt32
  let foreground: UInt32
  let accent: UInt32

  var backgroundColor: Color { Color(nsColor: backgroundNSColor) }
  var foregroundColor: Color { Color(nsColor: foregroundNSColor) }
  var accentColor: Color { Color(nsColor: accentNSColor) }
  var accentForegroundColor: Color { Color(nsColor: accentForegroundNSColor) }

  var backgroundNSColor: NSColor { Self.color(background) }
  var foregroundNSColor: NSColor { Self.color(foreground) }
  var accentNSColor: NSColor { Self.color(accent) }

  var accentForegroundNSColor: NSColor {
    let channels = Self.channels(accent)
    let luminance = 0.2126 * Self.linearized(channels.red)
      + 0.7152 * Self.linearized(channels.green)
      + 0.0722 * Self.linearized(channels.blue)
    let whiteContrast = 1.05 / (luminance + 0.05)
    let blackContrast = (luminance + 0.05) / 0.05
    return whiteContrast >= blackContrast ? .white : .black
  }

  private static func color(_ hex: UInt32) -> NSColor {
    let channels = channels(hex)
    return NSColor(
      srgbRed: channels.red,
      green: channels.green,
      blue: channels.blue,
      alpha: 1
    )
  }

  private static func channels(_ hex: UInt32) -> (red: CGFloat, green: CGFloat, blue: CGFloat) {
    (
      CGFloat((hex >> 16) & 0xFF) / 255,
      CGFloat((hex >> 8) & 0xFF) / 255,
      CGFloat(hex & 0xFF) / 255
    )
  }

  private static func linearized(_ channel: CGFloat) -> CGFloat {
    channel <= 0.04045
      ? channel / 12.92
      : pow((channel + 0.055) / 1.055, 2.4)
  }
}

private struct CapxThemeEnvironmentKey: EnvironmentKey {
  static let defaultValue = CapxTheme.light
}

extension EnvironmentValues {
  var capxTheme: CapxTheme {
    get { self[CapxThemeEnvironmentKey.self] }
    set { self[CapxThemeEnvironmentKey.self] = newValue }
  }
}
