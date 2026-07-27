# Third-party notices

CapX 0.1.0 does not bundle third-party source code, package dependencies, fonts, themes, or artwork.

The application links against Apple system frameworks provided by macOS, including AppKit, SwiftUI, Foundation, Combine, CoreGraphics, ImageIO, and UniformTypeIdentifiers. Those frameworks and the Swift toolchain are supplied under their respective Apple terms and are not redistributed as part of this repository's source license.

The CapX application icon and light/dark palettes are original project assets. Their provenance and licensing boundaries are documented in [`TRADEMARKS.md`](TRADEMARKS.md) and `Scripts/generate-icon.swift`.

GitHub Actions referenced by workflow files execute in GitHub's build environment and are not linked into or distributed with CapX. Their licenses are available in their upstream repositories.

If a future release adds a redistributable third-party component, this file must be updated before that release.
