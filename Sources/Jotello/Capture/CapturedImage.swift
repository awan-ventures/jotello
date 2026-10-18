import CoreGraphics
import Foundation

struct CapturedImage {
    let image: CGImage
    let pointSize: CGSize
    var appName: String?
    var windowTitle: String?
}

enum CaptureError: LocalizedError {
    case alreadyCapturing
    case permissionDenied
    case noDisplay
    case invalidRegion

    var errorDescription: String? {
        switch self {
        case .alreadyCapturing: return "A screenshot is already in progress."
        case .permissionDenied: return "Screen capture access is required."
        case .noDisplay: return "No available display could be captured."
        case .invalidRegion: return "The selected region could not be captured."
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .permissionDenied:
            return "Enable Jotello in System Settings → Privacy & Security → Screen Recording "
                + "(or Screen & System Audio Recording), then reopen Jotello. "
                + "Jotello only takes screenshots; it does not record video or audio."
        case .noDisplay, .invalidRegion: return "Try taking the screenshot again."
        case .alreadyCapturing: return "Finish the current selection or press Escape."
        }
    }
}
