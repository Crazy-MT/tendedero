import XCTest
@testable import PegNest

final class HistoryStoreTests: XCTestCase {
    var root: URL!
    var store: HistoryStore!
    override func setUpWithError() throws {
        root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        store = HistoryStore(folder: root.appendingPathComponent("History"), authorizedFolders: { [self.root.appendingPathComponent("External")] })
        try FileManager.default.createDirectory(at: root.appendingPathComponent("External"), withIntermediateDirectories: true)
    }
    override func tearDownWithError() throws { try FileManager.default.removeItem(at: root) }
    func testTextRoundTripAndExactDedup() throws {
        let value = " 中文\n\nA \t"
        let url = try store.capture(.text(value))
        XCTAssertEqual(try String(contentsOf: url, encoding: .utf8), value)
        XCTAssertEqual(try store.capture(.text(value)), url)
        XCTAssertNotEqual(try store.capture(.text(value + "\n")), url)
        XCTAssertEqual((try FileManager.default.attributesOfItem(atPath: url.path)[.posixPermissions] as? NSNumber)?.intValue, 0o600)
    }
    func testRestoreLimitAndPrivateCleanup() throws {
        let urls = try (0...100).map { try store.capture(.text("item \($0)")) }
        try store.save(urls)
        XCTAssertEqual(store.restore(limit: 100), Array(urls.suffix(100)))
        XCTAssertFalse(FileManager.default.fileExists(atPath: urls[0].path))
        let unrelated = store.folder.appendingPathComponent("unrelated.txt")
        try "keep".write(to: unrelated, atomically: true, encoding: .utf8)
        _ = store.restore(limit: 100)
        XCTAssertTrue(FileManager.default.fileExists(atPath: unrelated.path))
    }
    func testExternalPreservedAndUntrustedSymlinkRejected() throws {
        let external = root.appendingPathComponent("External/photo.png")
        try Data([1]).write(to: external)
        try store.removePrivateCopy(external)
        XCTAssertTrue(FileManager.default.fileExists(atPath: external.path))
        let outside = root.appendingPathComponent("outside.txt")
        try "secret".write(to: outside, atomically: true, encoding: .utf8)
        let link = root.appendingPathComponent("External/link.png")
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: outside)
        XCTAssertFalse(store.isAllowed(link))
        XCTAssertFalse(store.isAllowed(outside))
    }
    func testFailedCaptureIsObservable() throws {
        let file = root.appendingPathComponent("file")
        try Data().write(to: file)
        let broken = HistoryStore(folder: file, authorizedFolders: { [] })
        XCTAssertThrowsError(try broken.capture(.text("value")))
        XCTAssertTrue(broken.restore(limit: 100).isEmpty)
    }
    func testCorruptIndexDoesNotErasePrivateCopies() throws {
        let url = try store.capture(.text("recoverable"))
        try Data([0xff]).write(to: store.folder.appendingPathComponent("index.json"))
        XCTAssertEqual(store.restore(limit: 100), [url])
        XCTAssertTrue(store.recoveryFailed)
        let next = try store.capture(.text("next"))
        try store.save([url, next])
        XCTAssertEqual(store.restore(limit: 100), [url, next])
        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))
    }

    func testRecaptureRepairsCorruptPrivateCopy() throws {
        let url = try store.capture(.text("original"))
        try "corrupt".write(to: url, atomically: true, encoding: .utf8)
        XCTAssertEqual(try store.capture(.text("original")), url)
        XCTAssertEqual(try String(contentsOf: url, encoding: .utf8), "original")
    }

}
