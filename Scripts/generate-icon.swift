import AppKit
import CoreGraphics
import Foundation

// Original CapX icon geometry, authored for this project in 2026.
// No external artwork, fonts, symbols, or generated-image models are used.
private let canvasSize: CGFloat = 1024
private let fileManager = FileManager.default
private let scriptURL = URL(fileURLWithPath: CommandLine.arguments[0]).standardizedFileURL
private let repositoryRoot = scriptURL.deletingLastPathComponent().deletingLastPathComponent()
private let resourcesURL = repositoryRoot.appendingPathComponent("Resources", isDirectory: true)
private let iconsetURL = resourcesURL.appendingPathComponent("CapXIcon.iconset", isDirectory: true)
private let masterURL = resourcesURL.appendingPathComponent("CapXIcon-1024.png")
private let icnsURL = resourcesURL.appendingPathComponent("CapX.icns")

private struct IconVariant {
  let filename: String
  let size: Int
}

private let variants = [
  IconVariant(filename: "icon_16x16.png", size: 16),
  IconVariant(filename: "icon_16x16@2x.png", size: 32),
  IconVariant(filename: "icon_32x32.png", size: 32),
  IconVariant(filename: "icon_32x32@2x.png", size: 64),
  IconVariant(filename: "icon_128x128.png", size: 128),
  IconVariant(filename: "icon_128x128@2x.png", size: 256),
  IconVariant(filename: "icon_256x256.png", size: 256),
  IconVariant(filename: "icon_256x256@2x.png", size: 512),
  IconVariant(filename: "icon_512x512.png", size: 512),
  IconVariant(filename: "icon_512x512@2x.png", size: 1024),
]

private func color(_ hex: UInt32) -> CGColor {
  CGColor(
    srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
    green: CGFloat((hex >> 8) & 0xFF) / 255,
    blue: CGFloat(hex & 0xFF) / 255,
    alpha: 1
  )
}

private func fillRoundedRectangle(
  _ rectangle: CGRect,
  radius: CGFloat,
  color: CGColor,
  in context: CGContext
) {
  context.addPath(
    CGPath(
      roundedRect: rectangle,
      cornerWidth: radius,
      cornerHeight: radius,
      transform: nil
    )
  )
  context.setFillColor(color)
  context.fillPath()
}

private func drawIcon(in context: CGContext) {
  context.setAllowsAntialiasing(true)
  context.setShouldAntialias(true)

  fillRoundedRectangle(
    CGRect(x: 44, y: 44, width: 936, height: 936),
    radius: 220,
    color: color(0x15191D),
    in: context
  )

  fillRoundedRectangle(
    CGRect(x: 174, y: 326, width: 548, height: 404),
    radius: 78,
    color: color(0x36CFC3),
    in: context
  )

  fillRoundedRectangle(
    CGRect(x: 302, y: 198, width: 548, height: 404),
    radius: 78,
    color: color(0xF7F8FA),
    in: context
  )

  context.setStrokeColor(color(0x0B7471))
  context.setLineWidth(86)
  context.setLineCap(.round)
  context.move(to: CGPoint(x: 412, y: 298))
  context.addLine(to: CGPoint(x: 740, y: 502))
  context.strokePath()
  context.move(to: CGPoint(x: 740, y: 298))
  context.addLine(to: CGPoint(x: 412, y: 502))
  context.strokePath()
}

private func pngData(size: Int) -> Data {
  let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!
  let context = CGContext(
    data: nil,
    width: size,
    height: size,
    bitsPerComponent: 8,
    bytesPerRow: size * 4,
    space: colorSpace,
    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
  )!
  let scale = CGFloat(size) / canvasSize
  context.scaleBy(x: scale, y: scale)
  drawIcon(in: context)

  let image = context.makeImage()!
  let bitmap = NSBitmapImageRep(cgImage: image)
  return bitmap.representation(using: .png, properties: [:])!
}

try? fileManager.removeItem(at: iconsetURL)
try fileManager.createDirectory(at: iconsetURL, withIntermediateDirectories: true)

defer {
  try? fileManager.removeItem(at: iconsetURL)
}

for variant in variants {
  let destination = iconsetURL.appendingPathComponent(variant.filename)
  try pngData(size: variant.size).write(to: destination, options: .atomic)
}

try pngData(size: 1024).write(to: masterURL, options: .atomic)

let iconutil = Process()
iconutil.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
iconutil.arguments = ["-c", "icns", iconsetURL.path, "-o", icnsURL.path]
try iconutil.run()
iconutil.waitUntilExit()

guard iconutil.terminationStatus == 0 else {
  fatalError("iconutil failed with status \(iconutil.terminationStatus)")
}

print("Generated \(masterURL.path)")
print("Generated \(icnsURL.path)")
