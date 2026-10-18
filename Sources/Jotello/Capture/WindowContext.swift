import AppKit

/// An on-screen window from the system window list, in Quartz coordinates (top-left origin).
struct WindowInfo: Equatable {
    let processID: pid_t
    let appName: String?
    let title: String?
    let bounds: CGRect
    let layer: Int
}

enum WindowContext {
    /// Front-to-back list of normal on-screen windows. Titles need screen capture permission.
    static func onScreenWindows() -> [WindowInfo] {
        let options: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
        guard let list = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] else { return [] }
        return list.compactMap { entry in
            guard let pid = entry[kCGWindowOwnerPID as String] as? pid_t,
                  let boundsInfo = entry[kCGWindowBounds as String] as? NSDictionary,
                  let bounds = CGRect(dictionaryRepresentation: boundsInfo) else { return nil }
            return WindowInfo(processID: pid, appName: entry[kCGWindowOwnerName as String] as? String,
                              title: entry[kCGWindowName as String] as? String, bounds: bounds,
                              layer: entry[kCGWindowLayer as String] as? Int ?? 0)
        }
    }

    /// The frontmost normal window under the selection's center, excluding Jotello itself.
    /// `selection` is in AppKit desktop coordinates; `primaryHeight` is the menu-bar screen's height.
    static func window(under selection: CGRect, primaryHeight: CGFloat, windows: [WindowInfo],
                       excluding ownProcess: pid_t) -> WindowInfo? {
        let center = CGPoint(x: selection.midX, y: primaryHeight - selection.midY)
        return windows.first { $0.layer == 0 && $0.processID != ownProcess && $0.bounds.contains(center) }
    }
}
