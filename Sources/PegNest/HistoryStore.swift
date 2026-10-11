import Foundation
import CryptoKit

enum ClipboardContent: Equatable {
    case text(String)
    case image(Data)
}

/// Only clip-<SHA256> files are owned by the app. External originals are references.
final class HistoryStore {
    static let shared = HistoryStore(folder: FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("PegNest/History"), authorizedFolders: { FolderAccess.shared.urls })
    let folder: URL
    private let authorizedFolders: () -> [URL]
    private var index: URL { folder.appendingPathComponent("index.json") }
    private(set) var recoveryFailed = false

    init(folder: URL, authorizedFolders: @escaping () -> [URL]) {
        self.folder = folder
        self.authorizedFolders = authorizedFolders
    }

    func capture(_ content: ClipboardContent) throws -> URL {
        let data: Data
        let ext: String
        switch content {
        case .text(let value): data = Data(value.utf8); ext = "txt"
        case .image(let value): data = value; ext = "png"
        }
        guard data.count <= (ext == "txt" ? ClipboardPolicy.maxTextBytes : ClipboardPolicy.maxImageBytes) else { throw CocoaError(.fileWriteInvalidFileName) }
        let hash = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
        let url = folder.appendingPathComponent("clip-\(hash).\(ext)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        if FileManager.default.fileExists(atPath: url.path) {
            guard isPrivate(url) else { throw CocoaError(.fileReadNoPermission) }
            if try Data(contentsOf: url) == data { return url }
        }
        try data.write(to: url, options: .atomic)
        do { try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path) }
        catch { try? FileManager.default.removeItem(at: url); throw error }
        return url
    }

    func save(_ urls: [URL]) throws {
        guard urls.allSatisfy(isAllowed) else { throw CocoaError(.fileReadNoPermission) }
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        try JSONEncoder().encode(urls.map(\.path)).write(to: index, options: .atomic)
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: index.path)
    }

    func restore(limit: Int) -> [URL] {
        recoveryFailed = false
        let fm = FileManager.default
        do {
            let paths = try JSONDecoder().decode([String].self, from: Data(contentsOf: index))
            var seen = Set<String>()
            let allowed = paths.map { URL(fileURLWithPath: $0) }.filter {
                isAllowed($0) && fm.fileExists(atPath: $0.path) && seen.insert($0.path).inserted
            }
            let kept = Array(allowed.suffix(max(0, limit)))
            try save(kept)
            cleanup(keeping: kept)
            return kept
        } catch {
            // Recover managed copies before another capture can replace the damaged index.
            recoveryFailed = true
            guard let files = try? fm.contentsOfDirectory(at: folder, includingPropertiesForKeys: [.creationDateKey]) else { return [] }
            let recovered = files.filter(isPrivate).map { folder.appendingPathComponent($0.lastPathComponent) }.sorted {
                let a = (try? $0.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? .distantPast
                let b = (try? $1.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? .distantPast
                return a == b ? $0.path < $1.path : a < b
            }
            if recovered.isEmpty && !fm.fileExists(atPath: index.path) { recoveryFailed = false; return [] }
            let kept = Array(recovered.suffix(max(0, limit)))
            do { try save(kept); cleanup(keeping: kept) } catch { return recovered }
            return kept
        }
    }

    func isPrivate(_ url: URL) -> Bool {
        managedName(url)
            && url.deletingLastPathComponent().resolvingSymlinksInPath().standardizedFileURL.path
                == folder.resolvingSymlinksInPath().standardizedFileURL.path
            && contains(url, in: folder)
    }

    func isAllowed(_ url: URL) -> Bool {
        if isPrivate(url) { return true }
        guard ["png", "jpg", "jpeg", "heic", "tif", "tiff", "gif", "webp", "mov", "mp4"].contains(url.pathExtension.lowercased()) else { return false }
        return authorizedFolders().contains { contains(url, in: $0) }
    }

    func removePrivateCopy(_ url: URL) throws {
        guard isPrivate(url), FileManager.default.fileExists(atPath: url.path) else { return }
        try FileManager.default.removeItem(at: url)
    }

    private func cleanup(keeping urls: [URL]) {
        let keep = Set(urls.map(\.standardizedFileURL))
        guard let files = try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil) else { return }
        for file in files where isPrivate(file) && !keep.contains(file.standardizedFileURL) {
            try? removePrivateCopy(file)
        }
    }

    private func managedName(_ url: URL) -> Bool {
        let stem = url.deletingPathExtension().lastPathComponent
        let hash = stem.dropFirst(5)
        return stem.hasPrefix("clip-") && hash.count == 64 && hash.allSatisfy { "0123456789abcdef".contains($0) }
            && ["txt", "png"].contains(url.pathExtension)
    }

    private func contains(_ url: URL, in directory: URL) -> Bool {
        url.resolvingSymlinksInPath().standardizedFileURL.path.hasPrefix(directory.resolvingSymlinksInPath().standardizedFileURL.path + "/")
    }
}
