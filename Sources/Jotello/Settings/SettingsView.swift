import AppKit
import SwiftUI

struct SettingsView: View {
    @Bindable var loginItem: LoginItemModel
    let shortcutAvailable: Bool
    let capture: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(nsImage: NSApplication.shared.applicationIconImage)
                    .resizable().frame(width: 36, height: 36).accessibilityHidden(true)
                Text("Jotello").font(.headline)
                Spacer()
                Text("⌘ ⇧ 2").font(.callout).foregroundStyle(.secondary)
            }
            Button(action: capture) {
                Label("Capture Feedback", systemImage: "viewfinder").frame(maxWidth: .infinity)
            }.controlSize(.large).buttonStyle(.borderedProminent)
            Divider()
            Toggle("Launch at login", isOn: Binding(get: { loginItem.isEnabled }, set: { loginItem.setEnabled($0) }))
            if loginItem.needsApproval {
                Button("Allow in Login Items…", action: loginItem.openLoginSettings).font(.caption)
            }
            if !shortcutAvailable {
                Text("Shortcut in use. Start captures from the menu bar.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Button("Screen capture permission…") {
                if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") {
                    NSWorkspace.shared.open(url)
                }
            }.font(.caption)
        }
        .padding(20).frame(width: 340)
        .alert("Couldn’t change launch at login", isPresented: Binding(
            get: { loginItem.errorMessage != nil }, set: { if !$0 { loginItem.errorMessage = nil } }
        )) {
            Button("OK") { loginItem.errorMessage = nil }
        } message: { Text(loginItem.errorMessage ?? "") }
    }
}
