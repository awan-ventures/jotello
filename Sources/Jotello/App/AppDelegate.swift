import AppKit
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let capture = CaptureCoordinator()
    private let loginItem = LoginItemModel()
    private var statusItem: NSStatusItem?
    private var statusMenu: NSMenu?
    private var hotKey: GlobalHotKey?
    private var settingsWindow: NSWindow?
    private var editors: [UUID: EditorWindowController] = [:]
    private var captureTask: Task<Void, Never>?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Hosted unit tests must not register shortcuts or open UI.
        guard ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil else { return }
        installMainMenu()
        installStatusMenu()
        hotKey = GlobalHotKey { [weak self] in self?.newScreenshot() }
        #if DEBUG
        // Opens the editor on an image file without screen capture, for UI checks.
        if let path = ProcessInfo.processInfo.environment["JOTELLO_FIXTURE"],
           let image = NSImage(contentsOfFile: path)?.cgImage(forProposedRect: nil, context: nil, hints: nil) {
            openEditor(CapturedImage(image: image, pointSize: CGSize(width: image.width / 2, height: image.height / 2),
                                     appName: "Fixture", windowTitle: "Synthetic page"))
            return
        }
        #endif
        if !UserDefaults.standard.bool(forKey: "hasOpenedJotello") {
            UserDefaults.standard.set(true, forKey: "hasOpenedJotello")
            showSettings()
        }
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        loginItem.refresh()
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag { showSettings() }
        return true
    }

    func applicationWillTerminate(_ notification: Notification) {
        captureTask?.cancel()
        capture.cancel()
        hotKey?.unregister()
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        editors.values.forEach { $0.annotationDocument.commitEditing?() }
        guard editors.values.contains(where: \.hasUnsavedWork) else {
            return .terminateNow
        }
        let alert = NSAlert()
        alert.messageText = "Quit without sending your feedback?"
        alert.informativeText = "One or more screenshots have changes that haven’t been sent, copied or saved."
        alert.addButton(withTitle: "Keep Editing")
        alert.addButton(withTitle: "Discard and Quit")
        return alert.runModal() == .alertSecondButtonReturn ? .terminateNow : .terminateCancel
    }

    @objc func newScreenshot() {
        guard captureTask == nil, NSApp.modalWindow == nil else { return }
        captureTask = Task { [weak self] in
            guard let self else { return }
            defer { captureTask = nil }
            do {
                // Let the status menu dismiss before freezing the screen.
                try await Task.sleep(for: .milliseconds(180))
                if let captured = try await capture.captureRegion() {
                    openEditor(captured)
                }
            } catch is CancellationError {
                return
            } catch {
                presentError(error)
            }
        }
    }

    private func openEditor(_ captured: CapturedImage) {
        let id = UUID()
        let controller = EditorWindowController(capture: captured)
        controller.onClose = { [weak self] in self?.editors.removeValue(forKey: id) }
        editors[id] = controller
        controller.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
        controller.window?.makeKeyAndOrderFront(nil)
    }

    @objc func showSettings() {
        if settingsWindow == nil {
            let view = SettingsView(loginItem: loginItem, shortcutAvailable: hotKey?.isRegistered ?? false) {
                [weak self] in self?.newScreenshot()
            }
            let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 340, height: 230),
                                  styleMask: [.titled, .closable], backing: .buffered, defer: false)
            window.title = "Jotello"
            window.contentView = NSHostingView(rootView: view)
            window.isReleasedWhenClosed = false
            window.center()
            settingsWindow = window
        }
        loginItem.refresh()
        settingsWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc func showCaptures() {
        let root = CaptureStore.standard.root
        try? FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        NSWorkspace.shared.open(root)
    }

    private func presentError(_ error: Error) {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert(error: error)
        alert.runModal()
    }

    private func installStatusMenu() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        // The app icon's viewfinder and J, as a template so it follows the menu bar's appearance.
        let image = NSImage(named: "MenuBarIcon")
        image?.isTemplate = true
        image?.accessibilityDescription = "Jotello"
        item.button?.image = image
        item.button?.toolTip = "Jotello — Click to capture feedback. Right-click for more."
        item.button?.target = self
        item.button?.action = #selector(statusItemClicked(_:))
        item.button?.sendAction(on: [.leftMouseUp, .rightMouseUp])
        let menu = NSMenu()
        let captureItem = menu.addItem(withTitle: "Capture Feedback", action: #selector(newScreenshot), keyEquivalent: "2")
        captureItem.keyEquivalentModifierMask = [.command, .shift]
        captureItem.target = self
        menu.addItem(.separator())
        menu.addItem(withTitle: "Show Captures in Finder", action: #selector(showCaptures), keyEquivalent: "").target = self
        menu.addItem(withTitle: "Settings…", action: #selector(showSettings), keyEquivalent: ",").target = self
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit Jotello", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        statusMenu = menu
        statusItem = item
    }

    /// A single click starts a capture; a right-click or Control-click opens the menu.
    @objc private func statusItemClicked(_ sender: NSStatusBarButton) {
        let event = NSApp.currentEvent
        if event?.type == .rightMouseUp || event?.modifierFlags.contains(.control) == true {
            guard let statusItem, let statusMenu else { return }
            statusItem.menu = statusMenu
            sender.performClick(nil)
            statusItem.menu = nil
        } else {
            newScreenshot()
        }
    }

    private func installMainMenu() {
        let main = NSMenu()
        let app = NSMenu()
        app.addItem(withTitle: "Settings…", action: #selector(showSettings), keyEquivalent: ",").target = self
        app.addItem(.separator())
        app.addItem(withTitle: "Quit Jotello", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        main.addItem(withTitle: "Jotello", action: nil, keyEquivalent: "").submenu = app
        let edit = NSMenu(title: "Edit")
        edit.addItem(withTitle: "Undo", action: #selector(AnnotationCanvasView.undo(_:)), keyEquivalent: "z")
        let redo = edit.addItem(withTitle: "Redo", action: #selector(AnnotationCanvasView.redo(_:)), keyEquivalent: "z")
        redo.keyEquivalentModifierMask = [.command, .shift]
        edit.addItem(.separator())
        for (title, selector, key) in [("Cut", "cut:", "x"), ("Copy", "copy:", "c"),
                                       ("Paste", "paste:", "v"), ("Select All", "selectAll:", "a")] {
            edit.addItem(withTitle: title, action: Selector(selector), keyEquivalent: key)
        }
        main.addItem(withTitle: "Edit", action: nil, keyEquivalent: "").submenu = edit
        let windowMenu = NSMenu(title: "Window")
        windowMenu.addItem(withTitle: "Minimize", action: #selector(NSWindow.performMiniaturize(_:)), keyEquivalent: "m")
        windowMenu.addItem(withTitle: "Close", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")
        main.addItem(withTitle: "Window", action: nil, keyEquivalent: "").submenu = windowMenu
        NSApp.windowsMenu = windowMenu
        NSApp.mainMenu = main
    }
}
