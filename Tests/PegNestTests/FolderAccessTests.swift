import XCTest
@testable import PegNest

final class FolderAccessTests: XCTestCase {
    func testUnavailableBookmarksSurviveUnrelatedMutationAndCountTowardLimit() throws {
        let name = "PegNestTests.\(UUID())", defaults = UserDefaults(suiteName: name)!
        defer { defaults.removePersistentDomain(forName: name) }
        let broken = [Data([1]), Data([2]), Data([3])]
        defaults.set(broken, forKey: "watchedFolderBookmarks")
        let access = FolderAccess(defaults: defaults)
        access.remove(FileManager.default.temporaryDirectory)
        XCTAssertEqual(defaults.array(forKey: "watchedFolderBookmarks") as? [Data], broken)
        XCTAssertThrowsError(try access.add(FileManager.default.temporaryDirectory))
        XCTAssertTrue(access.recoveryFailed)
        XCTAssertEqual(defaults.array(forKey: "watchedFolderBookmarks") as? [Data], broken)
    }
    func testMalformedBookmarkDoesNotAuthorizePath() {
        let name = "PegNestTests.\(UUID())", defaults = UserDefaults(suiteName: name)!
        defer { defaults.removePersistentDomain(forName: name) }
        defaults.set([Data([1, 2, 3])], forKey: "watchedFolderBookmarks")
        let access = FolderAccess(defaults: defaults)
        XCTAssertTrue(access.urls.isEmpty)
        XCTAssertTrue(access.recoveryFailed)
        XCTAssertEqual(FolderAccess.maxFolders, 3)
        access.forgetUnavailable()
        XCTAssertFalse(access.recoveryFailed)
        XCTAssertEqual(access.savedCount, 0)
        XCTAssertEqual(defaults.array(forKey: "watchedFolderBookmarks") as? [Data], [])
    }
}
