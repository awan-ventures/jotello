# Verification

Run `./scripts/test.sh` for automated behavior and image-output tests, and `./scripts/build.sh` for a universal Release build. CI runs both on a Mac runner. Unit tests do not grant screen permission or prove the full desktop flow.

Snaplet's own dated verification log is in this repository's history (before the Jotello rename).

## Manual release checks

Use a signed build on macOS 14 and a current macOS version. These are checks to perform, not a claim that every configuration has been tested.

- **First run:** Launch from Applications; menu bar icon appears. Capture requests screen access only when needed. Deny permission, retry, then grant access. Follow a relaunch prompt if macOS shows one.
- **Selection:** Capture through both menu and ⌘⇧2. Drag in every direction and cancel with Esc. Click without dragging. Repeat on each display, including a display above or left of the main display and different scaling factors. Disconnect a display before a new capture.
- **Pixels:** Capture identifiable content near the edges. Check selection boundaries and exported PNG dimensions at Retina and non-Retina scales. Verify the screenshot and annotations have the same orientation.
- **Shapes:** Draw arrows, lines, rectangles, and ellipses. Change color/width, select, move, resize, and delete. Check short lines, reversed drag directions, and overlapping annotations.
- **Text:** Add English, Chinese, emoji, and multiple lines. Edit, recolor, enlarge, shrink, and move text. Cancel empty text entry. Check text near image boundaries and an active text edit during copy/save.
- **History:** Undo and redo creation, movement, resizing, text edits, style changes, and deletion. Undo all edits and redo them; make a new edit after undo and confirm old redo history is discarded.
- **Output:** Copy and paste into Preview or another image editor. Save through the native dialog, cancel, overwrite an existing PNG, and handle an unwritable destination without losing the open editor.
- **Lifecycle:** Start another capture with an editor open. Close an edited screenshot, cancel closing if prompted, and quit. Escape and keyboard shortcuts must work after repeatedly opening and closing editors.
- **Login:** Enable launch at login in a stable installed location, check System Settings, sign out/in, then disable and verify. Handle system approval or registration failure visibly.
- **Access:** Navigate controls with the keyboard and VoiceOver. Check light/dark mode, readable color controls, and a small display. Verify shortcuts while a text field has focus.

Record the actual OS versions, architectures, checks performed, and remaining gaps in the release PR or release notes.
