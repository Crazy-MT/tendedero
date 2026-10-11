import XCTest
import AppKit
@testable import PegNest

final class LineTests: XCTestCase {
    func testCaptureDedupCopyAndPrivateRemoval() async throws {
        await MainActor.run {
            let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
            defer { try? FileManager.default.removeItem(at: root) }
            let suite = "PegNestTests.\(UUID())", defaults = UserDefaults(suiteName: suite)!
            defer { defaults.removePersistentDomain(forName: suite) }
            let store = HistoryStore(folder: root, authorizedFolders: { [] })
            let line = Line(store: store, defaults: defaults, scheduleBreeze: false)
            line.maxItems = 2
            line.capture(.text(" 中文\n A \t")); line.capture(.text("second"))
            let first = line.items.first!.id
            line.capture(.text(" 中文\n A \t"))
            XCTAssertEqual(line.liveCount, 2)
            XCTAssertEqual(line.items.last!.id, first)
            let pb = NSPasteboard(name: .init(UUID().uuidString))
            defer { pb.releaseGlobally() }
            line.copy(first, to: pb)
            XCTAssertEqual(pb.string(forType: .string), " 中文\n A \t")
            XCTAssertTrue(pb.types!.contains(ClipboardPolicy.generated))
            XCTAssertEqual(line.items.last!.id, first)
            let oldURL = line.items.first!.url
            line.capture(.text("third"))
            XCTAssertEqual(line.liveCount, 2)
            XCTAssertFalse(FileManager.default.fileExists(atPath: oldURL.path))
            line.clear()
            XCTAssertEqual(line.liveCount, 0)
            XCTAssertEqual(pb.string(forType: .string), " 中文\n A \t")
            XCTAssertTrue(store.restore(limit: 100).isEmpty)
        }
    }
    func testFitModeDefersTrimmingUntilCapacityIsKnown() async throws {
        try await MainActor.run {
            let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
            defer { try? FileManager.default.removeItem(at: root) }
            let suite = "PegNestTests.\(UUID())", defaults = UserDefaults(suiteName: suite)!
            defer { defaults.removePersistentDomain(forName: suite) }
            defaults.set(0, forKey: "keepOnLine")
            let store = HistoryStore(folder: root, authorizedFolders: { [] })
            let urls = try (0..<12).map { try store.capture(.text("item \($0)")) }
            try store.save(urls)
            let line = Line(store: store, defaults: defaults, scheduleBreeze: false)
            XCTAssertEqual(line.liveCount, 12)
            XCTAssertTrue(urls.allSatisfy { FileManager.default.fileExists(atPath: $0.path) })
            line.maxItems = 10
            line.trim()
            XCTAssertEqual(line.liveCount, 10)
            XCTAssertEqual(store.restore(limit: 100), Array(urls.suffix(10)))
        }
    }
    func testRestartKeepsExactText() async throws {
        await MainActor.run {
            let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
            defer { try? FileManager.default.removeItem(at: root) }
            let store = HistoryStore(folder: root, authorizedFolders: { [] })
            let line = Line(store: store, scheduleBreeze: false)
            line.capture(.text("restart\n中文"))
            let restored = Line(store: store, scheduleBreeze: false)
            XCTAssertEqual(restored.items.first?.text, "restart\n中文")
        }
    }
    func testExternalOriginalAndExportArePreserved() async throws {
        try await MainActor.run {
            let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
            defer { try? FileManager.default.removeItem(at: root) }
            let external = root.appendingPathComponent("External")
            try FileManager.default.createDirectory(at: external, withIntermediateDirectories: true)
            let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 8, pixelsHigh: 8, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
            let original = external.appendingPathComponent("image.png")
            try rep.representation(using: .png, properties: [:])!.write(to: original)
            let store = HistoryStore(folder: root.appendingPathComponent("History"), authorizedFolders: { [external] })
            let line = Line(store: store, scheduleBreeze: false)
            let id = try XCTUnwrap(line.hang(original))
            let output = root.appendingPathComponent("Export.png")
            try line.exportCopy(id, to: output)
            XCTAssertEqual(try Data(contentsOf: output), try Data(contentsOf: original))
            XCTAssertEqual(line.liveCount, 1)
            line.clear()
            XCTAssertTrue(FileManager.default.fileExists(atPath: original.path))
            line.capture(.text("one"))
            let privateID = try XCTUnwrap(line.items.last?.id)
            let textExport = root.appendingPathComponent("Note.txt")
            try line.exportCopy(privateID, to: textExport)
            XCTAssertEqual(try String(contentsOf: textExport, encoding: .utf8), "one")
            XCTAssertEqual(line.liveCount, 1)
        }
    }

    func testRevokedDirectoryPrunesAllReferencesTogether() async throws {
        try await MainActor.run {
            let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
            defer { try? FileManager.default.removeItem(at: root) }
            let external = root.appendingPathComponent("External")
            try FileManager.default.createDirectory(at: external, withIntermediateDirectories: true)
            let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 8, pixelsHigh: 8, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
            var allowed = [external]
            let store = HistoryStore(folder: root.appendingPathComponent("History"), authorizedFolders: { allowed })
            let line = Line(store: store, scheduleBreeze: false)
            for name in ["one.png", "two.png"] {
                let file = external.appendingPathComponent(name)
                try rep.representation(using: .png, properties: [:])!.write(to: file)
                XCTAssertNotNil(line.hang(file))
            }
            allowed = []
            line.prune()
            XCTAssertEqual(line.liveCount, 0)
            XCTAssertTrue(store.restore(limit: 100).isEmpty)
            XCTAssertTrue(FileManager.default.fileExists(atPath: external.appendingPathComponent("one.png").path))
        }
    }
    func testSaveFailureDoesNotReportCopyOrRemoveExistingEntry() async throws {
        try await MainActor.run {
            let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
            defer { try? FileManager.default.removeItem(at: root) }
            let store = HistoryStore(folder: root, authorizedFolders: { [] })
            let line = Line(store: store, scheduleBreeze: false)
            line.capture(.text("keep"))
            let id = try XCTUnwrap(line.items.last?.id)
            try FileManager.default.removeItem(at: root.appendingPathComponent("index.json"))
            try FileManager.default.createDirectory(at: root.appendingPathComponent("index.json"), withIntermediateDirectories: true)
            var errors = 0; line.onError = { _ in errors += 1 }
            line.discard(id)
            XCTAssertEqual(line.liveCount, 1)
            XCTAssertTrue(FileManager.default.fileExists(atPath: line.items.last!.url.path))
            line.capture(.text("new"))
            XCTAssertEqual(line.liveCount, 1)
            XCTAssertGreaterThan(errors, 0)
        }
    }

}
