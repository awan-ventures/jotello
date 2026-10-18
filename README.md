<p align="center"><img src="Resources/Assets.xcassets/AppIcon.appiconset/icon_128x128@2x.png" width="112" alt="Jotello icon"></p>

# Jotello

Select something on your screen, mark what should change, then hand an agent-ready report to your existing workflow.

A small, local-first macOS menu-bar utility for visual feedback. It works on anything visible (browsers, desktop apps, localhost, staging, production). The plan is to hand reports off to GitHub, Jira, Trello, or your clipboard for Claude Code, Codex and other terminal agents. No account, no server, no telemetry.

[MIT license](LICENSE) · [Privacy](docs/PRIVACY.md) · [Plan](docs/PLAN.md)

**macOS 14 Sonoma or later · Swift + AppKit + SwiftUI · no dependencies**

## Status

Early development. Today it is Snaplet's capture-and-annotate flow under the Jotello name. The feedback composer and destination handoffs are next; see the [plan](docs/PLAN.md).

## Build and run

Install Xcode 15 or later. Optionally install [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`); the scripts regenerate the project when it is available.

```sh
./scripts/test.sh    # XCTest, ad hoc signed
./scripts/build.sh   # unsigned universal Release build → build/Build/Products/Release/Jotello.app
open Jotello.xcodeproj
```

Choose the **Jotello** scheme and **My Mac**, set your own team under Signing if Xcode asks, and Run.

## Use

1. Launch Jotello and click its menu bar icon, or press **⌘⇧2**.
2. Allow screen capture when macOS asks (System Settings → Privacy & Security → Screen & System Audio Recording). Jotello only captures still images, and only when you ask.
3. Drag to choose a region. **Return** captures the whole display; **Esc** cancels.
4. Add arrows, lines, rectangles, ellipses or text. Undo and redo with ⌘Z / ⇧⌘Z.
5. Copy the annotated image or save a PNG.

## Project layout

```text
Sources/Jotello/    App, capture, annotation editor, settings
Tests/JotelloTests/ Behavior and image-output checks
Resources/          Icon, Info.plist, entitlements, privacy manifest
scripts/            Build, test, icon generation
docs/               Plan, privacy, verification
project.yml         XcodeGen source of truth
```

Regenerate the app icon from [Resources/Icon.svg](Resources/Icon.svg) with `swift scripts/generate-icon.swift`.

## Credits

Jotello began as a fork of [Snaplet](https://github.com/jo9900/snaplet) by jo9900, used under the MIT license. Snaplet's commit history is preserved in this repository.

Made by [Adam Wan](https://madebyawan.com).
