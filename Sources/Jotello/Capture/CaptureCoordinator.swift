import AppKit
import ScreenCaptureKit

@MainActor
final class CaptureCoordinator {
    private(set) var isCapturing = false
    private var operationID: UUID?
    private var cancelled = false
    private var windows: [RegionSelectionWindow] = []
    private var continuation: CheckedContinuation<CapturedImage?, Error>?

    func captureRegion() async throws -> CapturedImage? {
        guard !isCapturing else { throw CaptureError.alreadyCapturing }
        isCapturing = true
        cancelled = false
        let id = UUID()
        operationID = id
        let previousApplication = NSWorkspace.shared.frontmostApplication
        var completed = false
        let displayObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                if self?.operationID == id { self?.cancel() }
            }
        }
        defer {
            NotificationCenter.default.removeObserver(displayObserver)
            windows.forEach { $0.orderOut(nil); $0.close() }
            windows.removeAll()
            continuation = nil
            operationID = nil
            isCapturing = false
            if !completed, previousApplication?.processIdentifier != ProcessInfo.processInfo.processIdentifier {
                previousApplication?.activate(options: [])
            }
        }
        return try await withTaskCancellationHandler {
            do {
                guard !cancelled, !Task.isCancelled else { return nil }
                let displays = try await freezeDisplays()
                guard !cancelled, !Task.isCancelled else { return nil }
                let result = try await selectRegion(from: displays)
                guard !cancelled, !Task.isCancelled else { return nil }
                completed = result != nil
                return result
            } catch {
                if cancelled || Task.isCancelled { return nil }
                let nsError = error as NSError
                if nsError.domain == SCStreamErrorDomain,
                   nsError.code == SCStreamError.Code.userDeclined.rawValue {
                    throw CaptureError.permissionDenied
                }
                throw error
            }
        } onCancel: {
            Task { @MainActor [weak self] in
                if self?.operationID == id { self?.cancel() }
            }
        }
    }

    func cancel() {
        cancelled = true
        finish(.success(nil))
    }

    private func freezeDisplays() async throws -> [(frame: CGRect, image: CGImage)] {
        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
        let ownApplications = content.applications.filter {
            $0.processID == ProcessInfo.processInfo.processIdentifier
        }
        var snapshots: [(frame: CGRect, image: CGImage)] = []
        // Capture every screen before showing any overlay, so overlays never enter a screenshot.
        for screen in NSScreen.screens {
            guard !cancelled, !Task.isCancelled else { throw CancellationError() }
            guard let number = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber,
                  let display = content.displays.first(where: { $0.displayID == number.uint32Value }) else {
                throw CaptureError.noDisplay
            }
            let filter = SCContentFilter(display: display, excludingApplications: ownApplications,
                                         exceptingWindows: [])
            let configuration = SCStreamConfiguration()
            let scale = CGFloat(filter.pointPixelScale)
            configuration.width = Int((filter.contentRect.width * scale).rounded())
            configuration.height = Int((filter.contentRect.height * scale).rounded())
            configuration.showsCursor = false
            configuration.capturesAudio = false
            configuration.captureResolution = .best
            let image = try await SCScreenshotManager.captureImage(contentFilter: filter,
                                                                  configuration: configuration)
            snapshots.append((screen.frame, image))
        }
        guard !snapshots.isEmpty else { throw CaptureError.noDisplay }
        return snapshots
    }

    private func selectRegion(from displays: [(frame: CGRect, image: CGImage)]) async throws -> CapturedImage? {
        try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
            for display in displays {
                let window = RegionSelectionWindow(image: display.image, frame: display.frame) { [weak self] rect in
                    guard let self else { return }
                    guard let rect else { self.cancel(); return }
                    let desktopRect = rect.offsetBy(dx: display.frame.minX, dy: display.frame.minY)
                    let pixelSize = CGSize(width: display.image.width, height: display.image.height)
                    guard let crop = CaptureGeometry.pixelRect(for: desktopRect, screenFrame: display.frame,
                                                              pixelSize: pixelSize),
                          let image = display.image.cropping(to: crop) else {
                        self.finish(.failure(CaptureError.invalidRegion))
                        return
                    }
                    let pointSize = CGSize(width: crop.width * display.frame.width / pixelSize.width,
                                           height: crop.height * display.frame.height / pixelSize.height)
                    self.finish(.success(CapturedImage(image: image, pointSize: pointSize)))
                }
                windows.append(window)
            }
            NSApp.activate(ignoringOtherApps: true)
            windows.forEach { $0.orderFrontRegardless() }
            let target = windows.first(where: { $0.frame.contains(NSEvent.mouseLocation) }) ?? windows.first
            target?.makeKey()
        }
    }

    private func finish(_ result: Result<CapturedImage?, Error>) {
        let pending = continuation
        continuation = nil
        pending?.resume(with: result)
    }
}
