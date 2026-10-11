import Foundation

/// Keeps security scopes alive while watchers and history references use them.
final class FolderAccess {
    static let shared = FolderAccess()
    static let maxFolders = 3
    private let defaults: UserDefaults
    private let key = "watchedFolderBookmarks"
    private(set) var urls: [URL] = []
    private(set) var recoveryFailed = false
    private var bookmarks: [Data] = []
    private var unresolved: [Data] = []
    private var accessed: Set<URL> = []

    init(defaults: UserDefaults = .standard) { self.defaults = defaults; restore() }
    deinit { accessed.forEach { $0.stopAccessingSecurityScopedResource() } }

    func restore() {
        accessed.forEach { $0.stopAccessingSecurityScopedResource() }
        accessed.removeAll(); urls.removeAll(); bookmarks.removeAll(); unresolved.removeAll(); recoveryFailed = false
        for data in (defaults.array(forKey: key) as? [Data] ?? []).prefix(Self.maxFolders) {
            do {
                var stale = false
                let url = try URL(resolvingBookmarkData: data, options: [.withSecurityScope, .withoutUI], relativeTo: nil, bookmarkDataIsStale: &stale)
                guard url.startAccessingSecurityScopedResource() else { recoveryFailed = true; unresolved.append(data); continue }
                accessed.insert(url)
                guard (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true else {
                    url.stopAccessingSecurityScopedResource(); accessed.remove(url); recoveryFailed = true; unresolved.append(data); continue
                }
                let renewed = stale ? try url.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil) : data
                urls.append(url); bookmarks.append(renewed)
            } catch { recoveryFailed = true; unresolved.append(data) }
        }
        // Preserve unresolved authorizations across unrelated folder changes.
        persist()
    }

    func add(_ url: URL) throws {
        guard !urls.contains(where: { $0.standardizedFileURL == url.standardizedFileURL }) else { return }
        guard bookmarks.count + unresolved.count < Self.maxFolders else { throw CocoaError(.fileWriteNoPermission) }
        let started = url.startAccessingSecurityScopedResource()
        do {
            guard (try url.resourceValues(forKeys: [.isDirectoryKey])).isDirectory == true else { throw CocoaError(.fileReadUnsupportedScheme) }
            let data = try url.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil)
            urls.append(url); bookmarks.append(data)
            if started { accessed.insert(url) }
            persist()
        } catch { if started { url.stopAccessingSecurityScopedResource() }; throw error }
    }

    func remove(_ url: URL) {
        guard let i = urls.firstIndex(of: url) else { return }
        urls.remove(at: i); bookmarks.remove(at: i)
        if accessed.remove(url) != nil { url.stopAccessingSecurityScopedResource() }
        persist()
    }
    var savedCount: Int { bookmarks.count + unresolved.count }
    func forgetUnavailable() {
        unresolved.removeAll(); recoveryFailed = false; persist()
    }
    private func persist() { defaults.set(bookmarks + unresolved, forKey: key) }
}
