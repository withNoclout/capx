# Contributing to CapX

Contributions are welcome when they keep CapX focused, local-only, and native to macOS.

## Prerequisites

- macOS 14 or later
- Xcode or the current Swift command-line tools
- Git

CapX has no third-party package dependencies.

## Local workflow

```sh
git clone https://github.com/withNoclout/capx.git
cd capx
swift build
swift test
./Scripts/build-app.sh debug
open dist/CapX.app
```

Run `swift Scripts/generate-icon.swift` only when intentionally changing the committed icon assets. The generated files must remain reproducible.

## Changes

1. Open an issue before a large behavioral or UI change so the scope can be agreed on.
2. Keep filesystem and image decoding work off the main actor. Keep observable UI state on the main actor.
3. Use public macOS APIs. Do not add private screenshot hooks, global input monitoring, analytics, telemetry, or network access.
4. Preserve original screenshot files: dismissing or clearing an item must never delete it from disk.
5. Add or update tests for new observable behavior. Do not test implementation text or incidental layout details.
6. Run `swift build` and `swift test`, then launch the packaged app and exercise the changed path.
7. Keep pull requests focused and explain user-visible behavior, privacy impact, and verification.

## Dependencies and assets

Discuss new dependencies before adding them. A proposal must explain why system frameworks are insufficient, the runtime and binary-size cost, the license, and the maintenance burden.

Do not submit artwork, fonts, themes, or code without clear rights and compatible license terms. Update `THIRD_PARTY_NOTICES.md` whenever a redistributable third-party component is introduced.

## Licensing and brand

By contributing source code, you agree that it may be distributed under the MIT License in `LICENSE`. The CapX name and icon are governed separately by `TRADEMARKS.md`; forks distributed under another identity must replace them.
