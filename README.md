<p align="center"><img src="Resources/Assets.xcassets/AppIcon.appiconset/icon_128x128@2x.png" width="112" alt="Jotello icon"></p>

# Jotello

Select something on your screen, mark what should change, then hand an agent-ready report to your existing workflow.

A small, local-first macOS menu-bar utility for visual feedback. It works on anything visible (browsers, desktop apps, localhost, staging, production). The plan is to hand reports off to GitHub, Jira, Trello, or your clipboard for Claude Code, Codex and other terminal agents. No account, no server, no telemetry.

[MIT license](LICENSE) · [Privacy](docs/PRIVACY.md) · [Plan](docs/PLAN.md)

**macOS 14 Sonoma or later · Swift + AppKit + SwiftUI · no dependencies**

## Status

Early development: the local P0 MVP. Capture, annotation, the feedback composer, and the Claude Code, Codex, GitHub (browser or `gh`) and clipboard handoffs work. Jira and Trello and Developer ID signing come next; see the [plan](docs/PLAN.md).

## Download

Get the latest zip from [Releases](https://github.com/madebyawan/jotello/releases/latest), unzip it and move **Jotello.app** to Applications. Builds aren't signed with a Developer ID yet, so the first launch is blocked: open **System Settings → Privacy & Security** and click **Open Anyway**. Pushing a `v*` tag builds, tests and publishes a release.

## Build and run

Install Xcode 15 or later. Optionally install [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`); the scripts regenerate the project when it is available.

```sh
./scripts/test.sh    # XCTest, ad hoc signed
./scripts/build.sh   # unsigned universal Release build → build/Build/Products/Release/Jotello.app
open Jotello.xcodeproj
```

Choose the **Jotello** scheme and **My Mac**, set your own team under Signing if Xcode asks, and Run. macOS ties the screen capture permission to the app's signature, so an ad hoc build may ask again after each rebuild.

Debug builds can skip capture for UI work: `JOTELLO_FIXTURE=/path/to/image.png build/Build/Products/Debug/Jotello.app/Contents/MacOS/Jotello` opens the editor on that image.

## Use

1. Launch Jotello and **click its menu bar icon**, or press **⌘⇧2**. Right-click the icon for Settings, the captures folder and Quit.
2. Allow screen capture when macOS asks (System Settings → Privacy & Security → Screen & System Audio Recording). Jotello only captures still images, and only when you ask.
3. Drag to choose a region. **Return** captures the whole display; **Esc** cancels.
4. Mark it up with arrows, lines, boxes, ellipses or text. Undo and redo with ⌘Z / ⇧⌘Z.
5. In the panel on the right, choose a type (Bug, UX improvement, Polish, Other), describe what should change and optionally add the page URL. The title is generated from your description if you leave it empty.
6. Choose where it goes and press the send button (⇧⌘↩):

| Send to | What Jotello does | What you do |
| --- | --- | --- |
| Claude Code | With a project folder: opens Terminal there and runs `claude` with the prompt and access to the screenshot. Without one: copies the prompt | Work with Claude Code as usual |
| Codex | With a project folder: opens Terminal there and runs `codex` with the prompt and the screenshot attached. Without one: copies the prompt | Work with Codex as usual |
| New GitHub issue | Opens `issues/new` with the title and description filled in, and copies the image | Paste (⌘V) the image into the description, review, submit |
| GitHub PR or issue comment | Opens the conversation and copies a Markdown comment | Paste the comment, use **Copy Image** for the screenshot, submit |
| Clipboard (any agent) | Copies a task prompt with the screenshot's absolute path | Paste it anywhere |

**Post with GitHub CLI (gh)** is an option for both GitHub destinations. Jotello opens Terminal and shows the post. It runs `gh issue create`, `gh pr comment` or `gh issue comment` with your own `gh` login only after you type `y`, then opens the result so you can paste the screenshot. Neither GitHub's API nor `gh` can attach an image the way the browser does.

Agent and `gh` launches run in your login shell, so they find `claude`, `codex` and `gh` on your usual PATH. Each one is a `.command` file next to the capture, which you can read.

Jotello never posts anything without your confirmation. Each send saves `screenshot.png`, `feedback.json` and `prompt.md` to `~/Library/Application Support/Jotello/Captures/<date>-<title>/`. Jotello remembers your last destination and the URL or folder you used with each one.

## Project layout

```text
Sources/Jotello/    App, capture, annotation editor, feedback composer and handoff, settings
Tests/JotelloTests/ Behavior and image-output checks
Resources/          Icon, Info.plist, privacy manifest
scripts/            Build, test, icon generation
docs/               Plan, privacy, verification
project.yml         XcodeGen source of truth
```

Regenerate the app icon from [Resources/Icon.svg](Resources/Icon.svg) with `swift scripts/generate-icon.swift`.

## Credits

Jotello began as a fork of [Snaplet](https://github.com/jo9900/snaplet) by jo9900, used under the MIT license. Snaplet's commit history is preserved in this repository.

Made by [Adam Wan](https://madebyawan.com).
