import XCTest
import AppKit
@testable import PegNest

final class ClipboardWatcherTests: XCTestCase {
    func testStartPauseAndStaleCompletion() async {
        await MainActor.run {
            let pb = NSPasteboard(name: .init(UUID().uuidString))
            defer { pb.releaseGlobally() }
            pb.setString("old", forType: .string)
            var captured: [ClipboardContent] = []
            let watcher = ClipboardWatcher(pasteboard: pb) { captured.append($0) }
            watcher.start(); watcher.check()
            XCTAssertTrue(captured.isEmpty)
            pb.clearContents(); pb.setString(" 中文\nA", forType: .string); watcher.check()
            XCTAssertEqual(captured, [.text(" 中文\nA")])
            let generation = watcher.generation, count = pb.changeCount
            watcher.stop(); watcher.start()
            watcher.acceptDecoded(.text("stale"), count: count, generation: generation)
            XCTAssertEqual(captured.count, 1)
            pb.clearContents(); pb.setString("new", forType: .string)
            watcher.acceptDecoded(.text("stale"), count: count, generation: watcher.generation)
            XCTAssertEqual(captured.count, 1)
            watcher.stop(); watcher.check()
            XCTAssertEqual(captured.count, 1)
        }
    }
}
