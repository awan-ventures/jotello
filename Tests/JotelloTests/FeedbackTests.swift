import XCTest
@testable import Jotello

final class FeedbackTests: XCTestCase {
    private let context = CaptureContext(appName: "Google Chrome", windowTitle: "Checkout – Shop",
                                         pixelWidth: 1600, pixelHeight: 900)

    private func draft(_ change: (inout FeedbackDraft) -> Void = { _ in }) -> FeedbackDraft {
        var draft = FeedbackDraft(context: context)
        change(&draft)
        return draft
    }

    func testResolvedTitlePrefersTypedThenFirstLineThenCategory() {
        XCTAssertEqual(draft { $0.title = "  Fix button  " }.resolvedTitle, "Fix button")
        XCTAssertEqual(draft { $0.description = "\n  Pay button overlaps footer\nmore" }.resolvedTitle,
                       "Pay button overlaps footer")
        XCTAssertEqual(draft { $0.category = .polish }.resolvedTitle, "Polish feedback in Google Chrome")
        let long = draft { $0.description = String(repeating: "a", count: 100) }.resolvedTitle
        XCTAssertEqual(long.count, 72)
        XCTAssertTrue(long.hasSuffix("…"))
    }

    func testGitHubTargetParsing() {
        XCTAssertEqual(GitHubTarget("https://github.com/awan-ventures/jotello")?.repo, "jotello")
        XCTAssertEqual(GitHubTarget("github.com/a/b.git")?.repo, "b")
        let pull = GitHubTarget("https://github.com/a/b/pull/42/files#diff")
        XCTAssertEqual(pull?.conversationURL?.absoluteString, "https://github.com/a/b/pull/42")
        XCTAssertEqual(GitHubTarget("https://github.com/a/b/issues/7")?.conversationURL?.absoluteString,
                       "https://github.com/a/b/issues/7")
        XCTAssertNil(GitHubTarget("https://github.com/a/b")?.conversationURL)
        XCTAssertNil(GitHubTarget("https://gitlab.com/a/b"))
        XCTAssertNil(GitHubTarget("https://github.com/a"))
        XCTAssertNil(GitHubTarget(""))
    }

    func testIssueURLPrefillsEncodedTitleAndBody() throws {
        let url = try XCTUnwrap(DestinationAdapter.url(for: draft {
            $0.destination = .githubIssue
            $0.targetURL = "https://github.com/a/b/tree/main"
            $0.title = "C++ & you"
            $0.description = "Line one\nLine two"
        }))
        XCTAssertTrue(url.absoluteString.hasPrefix("https://github.com/a/b/issues/new?"))
        let items = try XCTUnwrap(URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems)
        XCTAssertEqual(items.first { $0.name == "title" }?.value, "C++ & you")
        XCTAssertTrue(url.absoluteString.contains("C%2B%2B"))
        let body = try XCTUnwrap(items.first { $0.name == "body" }?.value)
        XCTAssertTrue(body.contains("Line one\nLine two"))
        XCTAssertTrue(body.contains("Google Chrome — Checkout – Shop"))
    }

    func testLongIssueBodyIsLeftOutOfURL() throws {
        let url = try XCTUnwrap(DestinationAdapter.url(for: draft {
            $0.destination = .githubIssue
            $0.targetURL = "https://github.com/a/b"
            $0.description = String(repeating: "x", count: DestinationAdapter.maxBodyLength + 1)
        }))
        XCTAssertFalse(url.absoluteString.contains("body="))
    }

    func testDestinationValidation() throws {
        XCTAssertNil(try DestinationAdapter.url(for: draft()))
        XCTAssertThrowsError(try DestinationAdapter.url(for: draft { $0.destination = .githubIssue })) {
            XCTAssertEqual($0 as? DestinationError, .missingRepository)
        }
        XCTAssertThrowsError(try DestinationAdapter.url(for: draft {
            $0.destination = .githubComment
            $0.targetURL = "https://github.com/a/b"
        })) { XCTAssertEqual($0 as? DestinationError, .missingConversation) }
    }

    func testAgentPromptHasAbsolutePathButIssueBodyDoesNot() {
        let feedback = draft { $0.description = "Make it blue"; $0.sourceURL = "http://localhost:3000/cart" }
        let prompt = FeedbackFormatter.agentPrompt(feedback, screenshotPath: "/Users/x/shot.png")
        XCTAssertTrue(prompt.contains("Screenshot (1600 × 900 px): /Users/x/shot.png"))
        XCTAssertTrue(prompt.contains("Page: http://localhost:3000/cart"))
        XCTAssertTrue(prompt.contains("Make it blue"))
        XCTAssertFalse(FeedbackFormatter.issueBody(feedback).contains("/Users/"))
        XCTAssertTrue(FeedbackFormatter.markdown(feedback).hasPrefix("### Make it blue"))
    }

    func testHandoffSavesBundleAndCopiesPrompt() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let png = Data([0x89, 0x50, 0x4E, 0x47])
        let handoff = try FeedbackHandoff.prepare(draft: draft { $0.title = "Fix: the cart!" }, png: png,
                                                  store: CaptureStore(root: root))
        let path = try XCTUnwrap(handoff.draft.screenshotPath)
        XCTAssertTrue(path.hasPrefix(root.path))
        XCTAssertTrue(path.contains("-fix-the-cart/screenshot.png"))
        XCTAssertEqual(try Data(contentsOf: URL(fileURLWithPath: path)), png)
        let folder = URL(fileURLWithPath: path).deletingLastPathComponent()
        let json = try Data(contentsOf: folder.appendingPathComponent("feedback.json"))
        XCTAssertEqual(try decoder().decode(FeedbackDraft.self, from: json).screenshotPath, path)
        XCTAssertTrue(FileManager.default.fileExists(atPath: folder.appendingPathComponent("prompt.md").path))
        guard case .text(let text) = handoff.clipboard else { return XCTFail("Expected a text prompt") }
        XCTAssertTrue(text.contains(path))
        XCTAssertNil(handoff.url)
    }

    func testInvalidDestinationWritesNothing() {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        XCTAssertThrowsError(try FeedbackHandoff.prepare(draft: draft { $0.destination = .githubComment },
                                                         png: Data([1]), store: CaptureStore(root: root)))
        XCTAssertFalse(FileManager.default.fileExists(atPath: root.path))
    }

    func testIssueHandoffCopiesImageAndOpensPrefilledPage() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let handoff = try FeedbackHandoff.prepare(draft: draft {
            $0.destination = .githubIssue
            $0.targetURL = "https://github.com/a/b"
        }, png: Data([1]), store: CaptureStore(root: root))
        XCTAssertEqual(handoff.clipboard, .image)
        XCTAssertEqual(handoff.url?.path, "/a/b/issues/new")
    }

    @MainActor
    func testModelRemembersDestinationAfterSendOnly() throws {
        let defaults = try XCTUnwrap(UserDefaults(suiteName: "JotelloTests-\(UUID().uuidString)"))
        let model = FeedbackModel(context: context, defaults: defaults)
        XCTAssertEqual(model.draft.destination, .agent)
        XCTAssertFalse(model.hasUnsentText)
        model.draft.destination = .githubComment
        model.draft.targetURL = " https://github.com/a/b/pull/1 "
        model.draft.description = "Hi"
        XCTAssertTrue(model.hasUnsentText)
        XCTAssertEqual(FeedbackModel(context: context, defaults: defaults).draft.destination, .agent)
        model.markSent(model.draft)
        XCTAssertFalse(model.hasUnsentText)
        let next = FeedbackModel(context: context, defaults: defaults)
        XCTAssertEqual(next.draft.destination, .githubComment)
        XCTAssertEqual(next.draft.targetURL, "https://github.com/a/b/pull/1")
    }

    func testWindowUnderSelectionUsesQuartzCoordinatesAndSkipsOwnAndOverlayWindows() {
        let windows = [
            WindowInfo(processID: 1, appName: "Jotello", title: nil, bounds: CGRect(x: 0, y: 0, width: 500, height: 500), layer: 0),
            WindowInfo(processID: 2, appName: "Dock", title: nil, bounds: CGRect(x: 0, y: 0, width: 500, height: 500), layer: 20),
            WindowInfo(processID: 3, appName: "Safari", title: "Top", bounds: CGRect(x: 0, y: 0, width: 400, height: 200), layer: 0),
            WindowInfo(processID: 4, appName: "Notes", title: "Bottom", bounds: CGRect(x: 0, y: 600, width: 400, height: 400), layer: 0)
        ]
        // A selection near the top of a 1000-point-high screen in AppKit coordinates.
        let top = WindowContext.window(under: CGRect(x: 50, y: 850, width: 100, height: 100), primaryHeight: 1000,
                                       windows: windows, excluding: 1)
        XCTAssertEqual(top?.appName, "Safari")
        let bottom = WindowContext.window(under: CGRect(x: 50, y: 50, width: 100, height: 100), primaryHeight: 1000,
                                          windows: windows, excluding: 1)
        XCTAssertEqual(bottom?.title, "Bottom")
        XCTAssertNil(WindowContext.window(under: CGRect(x: 800, y: 50, width: 10, height: 10), primaryHeight: 1000,
                                          windows: windows, excluding: 1))
    }

    private func decoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
