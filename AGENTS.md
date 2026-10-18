# Jotello

Read `README.md` and `docs/PLAN.md` before changing this repository.

- Native macOS 14+ app in Swift, AppKit and SwiftUI. Keep it dependency-free.
- Capture still images with ScreenCaptureKit, and only on an explicit user action. No recording, OCR, analytics, accounts or backend.
- No built-in browser. Never claim a screenshot was attached or posted remotely: handoff is clipboard, local file and opening a prefilled page in the user's browser.
- Annotation preview and export must use the same renderer. Preserve source pixel dimensions; document coordinates are logical points with the origin at the top left.
- Finish pending text input before export and preserve input-method composition. Group each gesture into one undo operation. Cancel must restore the prior state and never send anything.
- Keep files focused and short. Keep the editor UI compact.
- `project.yml` is the XcodeGen source of truth. Regenerate and commit the Xcode project after adding or removing source files.
- Run `./scripts/test.sh` for behavior checks and `./scripts/build.sh` for the Release build. See `docs/TESTING.md` for manual permission and display checks.
- Keep Snaplet's MIT copyright notice in `LICENSE`. Documentation screenshots must use synthetic content.
