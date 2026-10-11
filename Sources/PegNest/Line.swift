import AppKit
import AVFoundation
import Combine
import os
import UniformTypeIdentifiers

let log = Logger(subsystem: Bundle.main.bundleIdentifier ?? "local.PegNest", category: "line")

struct Pegged: Identifiable, Equatable {
    let id = UUID()
    let url: URL
    var thumb: NSImage
    let tilt = Double.random(in: -2.5...2.5)
    var falling = false
    var flying = false
    var text: String?
    var isRecording: Bool { PegNest.isRecording(url) }
    static func == (a: Pegged, b: Pegged) -> Bool {
        a.id == b.id && a.falling == b.falling && a.flying == b.flying && a.thumb === b.thumb
    }
}

@MainActor
final class Line: ObservableObject {
    @Published private(set) var items: [Pegged] = []
    @Published private(set) var gust = 0
    @Published var copiedID: UUID?
    @Published var draggingID: UUID?
    @Published var pressedID: UUID?
    @Published var revealed = false
    @Published var scroll: CGFloat = 0
    var hitRects: [UUID: CGRect] = [:]
    var maxItems = 100
    var visibleCount = 8
    var onFall: ((Pegged) -> Void)?
    var onError: (String) -> Void = { _ in NSSound.beep() }
    let store: HistoryStore
    private let defaults: UserDefaults

    nonisolated static let keepChoices = [25, 50, 100]
    nonisolated static var keepOnLine: Int? {
        get {
            guard UserDefaults.standard.object(forKey: "keepOnLine") != nil else { return 100 }
            let n = UserDefaults.standard.integer(forKey: "keepOnLine")
            return keepChoices.contains(n) ? n : nil
        }
        set { UserDefaults.standard.set(newValue ?? 0, forKey: "keepOnLine") }
    }
    var soundOn: Bool {
        get { !defaults.bool(forKey: "soundOff") }
        set { defaults.set(!newValue, forKey: "soundOff") }
    }
    var liveCount: Int { items.filter { !$0.falling }.count }
    private var liveURLs: [URL] { items.filter { !$0.falling }.map(\.url) }

    init(store: HistoryStore = .shared, defaults: UserDefaults = .standard, scheduleBreeze: Bool = true) {
        self.store = store; self.defaults = defaults
        let configured = defaults.object(forKey: "keepOnLine") == nil ? 100 : defaults.integer(forKey: "keepOnLine")
        // Fit capacity is measured by AppDelegate after panel placement.
        maxItems = Self.keepChoices.contains(configured) ? configured : 100
        for url in store.restore(limit: maxItems) {
            if let item = makeItem(url) { items.append(item) }
        }
        if scheduleBreeze { scheduleGust() }
    }

    func capture(_ content: ClipboardContent) {
        do {
            let url = try store.capture(content)
            if let i = items.firstIndex(where: { $0.url == url && !$0.falling }) {
                let previous = items
                var item = items.remove(at: i)
                if let updated = makeItem(url) { item.text = updated.text; item.thumb = updated.thumb }
                items.append(item)
                guard save() else { items = previous; return }
                scroll = 0
            } else if hang(url) == nil { try store.removePrivateCopy(url) }
        } catch { onError(L("Could not save clipboard history.")) }
    }

    @discardableResult
    func hang(_ url: URL, quietly: Bool = false, flying: Bool = false) -> UUID? {
        guard store.isAllowed(url), !items.contains(where: { $0.url == url && !$0.falling }),
              var item = makeItem(url) else { return nil }
        item.flying = flying
        items.append(item)
        guard save() else { items.removeAll { $0.id == item.id }; return nil }
        scroll = 0
        trim()
        if !quietly { play("Tink", volume: 0.35) }
        return item.id
    }

    private func makeItem(_ url: URL) -> Pegged? {
        guard store.isAllowed(url) else { return nil }
        if store.isPrivate(url), url.pathExtension == "txt" {
            guard let data = try? Data(contentsOf: url), data.count <= ClipboardPolicy.maxTextBytes,
                  let text = String(data: data, encoding: .utf8), ClipboardPolicy.text(text) != nil else { return nil }
            return Pegged(url: url, thumb: textThumbnail(text), text: text)
        }
        guard let thumb = makeThumbnail(url) else { return nil }
        return Pegged(url: url, thumb: thumb)
    }
    func land(_ id: UUID) { if let i = items.firstIndex(where: { $0.id == id }) { items[i].flying = false } }

    func drop(_ id: UUID, quietly: Bool = false) {
        guard let i = items.firstIndex(where: { $0.id == id }), !items[i].falling else { return }
        let remaining = items.filter { !$0.falling && $0.id != id }.map(\.url)
        do { try store.save(remaining) } catch { onError(L("Could not update clipboard history.")); return }
        animateDrop(id, quietly: quietly)
    }
    private func animateDrop(_ id: UUID, quietly: Bool) {
        guard let i = items.firstIndex(where: { $0.id == id }) else { return }
        onFall?(items[i]); items[i].falling = true; hitRects[id] = nil
        if !quietly { play("Pop", volume: 0.25) }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [weak self] in self?.items.removeAll { $0.id == id } }
    }
    func clear() { for item in items.filter({ !$0.falling }) { discard(item.id, quietly: true) } }
    func neighbours(of id: UUID, toTheLeft: Bool) -> [Pegged] {
        let live = items.filter { !$0.falling }
        guard let i = live.firstIndex(where: { $0.id == id }) else { return [] }
        return toTheLeft ? Array(live[..<i]) : Array(live[(i + 1)...])
    }
    func takeDown(_ id: UUID, toTheLeft: Bool) { for item in neighbours(of: id, toTheLeft: toTheLeft) { discard(item.id) } }
    func prune() {
        let invalid = items.filter { !$0.falling && (!store.isAllowed($0.url) || !FileManager.default.fileExists(atPath: $0.url.path)) }
        guard !invalid.isEmpty else { return }
        let ids = Set(invalid.map(\.id))
        do {
            try store.save(items.filter { !$0.falling && !ids.contains($0.id) }.map(\.url))
            invalid.forEach { animateDrop($0.id, quietly: true) }
        } catch { onError(L("Could not update clipboard history.")) }
    }
    func copy(_ id: UUID, to pb: NSPasteboard = .general) {
        guard let item = items.first(where: { $0.id == id && !$0.falling }), store.isAllowed(item.url) else { return }
        let entry = NSPasteboardItem()
        if let text = item.text { entry.setString(text, forType: .string) }
        else if item.isRecording { entry.setString(item.url.absoluteString, forType: .fileURL) }
        else {
            guard let png = pngData(item.url) else { onError(L("Could not copy this item.")); return }
            entry.setData(png, forType: .png)
        }
        entry.setData(Data(), forType: ClipboardPolicy.generated)
        pb.clearContents()
        guard pb.writeObjects([entry]) else { onError(L("Could not copy this item.")); return }
        copiedID = id
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { [weak self] in if self?.copiedID == id { self?.copiedID = nil } }
    }
    func open(_ id: UUID) {
        guard let item = items.first(where: { $0.id == id }), store.isAllowed(item.url) else { return }
        if let text = item.text { TextPreview.shared.show(text) } else { NSWorkspace.shared.open(item.url) }
    }
    @discardableResult
    func trash(_ id: UUID, quietly: Bool = false) -> Bool {
        guard let item = items.first(where: { $0.id == id }), store.isAllowed(item.url) else { return false }
        if store.isPrivate(item.url) { discard(id, quietly: quietly); return !items.contains { $0.id == id && !$0.falling } }
        do { try FileManager.default.trashItem(at: item.url, resultingItemURL: nil); drop(id, quietly: quietly); return true }
        catch { onError(L("Could not remove this item.")); return false }
    }
    func isInInbox(_ id: UUID) -> Bool { items.first(where: { $0.id == id }).map { store.isPrivate($0.url) } ?? false }
    func discard(_ id: UUID, quietly: Bool = false) {
        guard let item = items.first(where: { $0.id == id && !$0.falling }) else { return }
        let old = liveURLs, remaining = old.filter { $0 != item.url }
        do {
            try store.save(remaining)
            do { try store.removePrivateCopy(item.url) }
            catch { try store.save(old); throw error }
            animateDrop(id, quietly: quietly)
        } catch { onError(L("Could not remove this item.")) }
    }
    func scroll(by delta: CGFloat) {
        let most = CGFloat(max(0, liveCount - visibleCount)) * Layout.spacing
        scroll = min(most, max(0, scroll + delta))
    }
    func trim() {
        while liveCount > maxItems, let oldest = items.first(where: { !$0.falling }) {
            let before = liveCount
            discard(oldest.id, quietly: true)
            if before == liveCount { break }
        }
        scroll = 0
    }
    func export(_ id: UUID) {
        guard let item = items.first(where: { $0.id == id }), store.isAllowed(item.url) else { return }
        let panel = NSSavePanel()
        panel.nameFieldStringValue = item.text != nil ? "Note.txt" : "Image.\(item.url.pathExtension)"
        panel.allowedContentTypes = [UTType(filenameExtension: item.url.pathExtension) ?? .data]
        NSApp.activate(ignoringOtherApps: true)
        guard panel.runModal() == .OK, let target = panel.url else { return }
        do { try exportCopy(id, to: target) } catch { onError(L("Could not export this item.")) }
    }
    func exportCopy(_ id: UUID, to target: URL) throws {
        guard let item = items.first(where: { $0.id == id }), store.isAllowed(item.url) else { throw CocoaError(.fileReadNoPermission) }
        guard target.standardizedFileURL != item.url.standardizedFileURL else { return }
        try Data(contentsOf: item.url).write(to: target, options: .atomic)
    }
    func markup(_ id: UUID) {
        guard let item = items.first(where: { $0.id == id }), store.isAllowed(item.url) else { return }
        if item.text != nil { open(id) }
        else if item.isRecording { Trim.shared.edit(item.url, size: item.thumb.size) }
        else { Markup.shared.edit(item.url) }
    }
    func reloadThumbnail(for url: URL) {
        guard store.isAllowed(url), let i = items.firstIndex(where: { $0.url == url && !$0.falling }), let thumb = makeThumbnail(url) else { return }
        items[i].thumb = thumb
    }
    func quickLook(_ id: UUID) {
        let live = items.filter { !$0.falling && store.isAllowed($0.url) }
        guard let index = live.firstIndex(where: { $0.id == id }) else { return }
        QuickLook.shared.show(live.map(\.url), at: index)
    }
    func reloadThumbnails() { for item in items where item.text == nil { reloadThumbnail(for: item.url) } }
    func reveal(_ id: UUID) {
        guard let item = items.first(where: { $0.id == id }), store.isAllowed(item.url) else { return }
        NSWorkspace.shared.activateFileViewerSelecting([item.url])
    }
    private func scheduleGust() {
        DispatchQueue.main.asyncAfter(deadline: .now() + .random(in: 7...16)) { [weak self] in
            guard let self else { return }
            if !self.items.isEmpty && self.draggingID == nil { self.gust += 1 }
            self.scheduleGust()
        }
    }
    @discardableResult private func save() -> Bool {
        do { try store.save(liveURLs); return true } catch { onError(L("Could not update clipboard history.")); return false }
    }
    private func play(_ name: String, volume: Float) {
        guard soundOn, let sound = NSSound(named: name)?.copy() as? NSSound else { return }
        sound.volume = volume; sound.play()
    }
    private func pngData(_ url: URL) -> Data? {
        if url.pathExtension.lowercased() == "png" { return try? Data(contentsOf: url) }
        guard let tiff = NSImage(contentsOf: url)?.tiffRepresentation, let rep = NSBitmapImageRep(data: tiff) else { return nil }
        return rep.representation(using: .png, properties: [:])
    }
}

/// A private note thumbnail; full original text stays in the model and file.
func textThumbnail(_ text: String) -> NSImage {
    let image = NSImage(size: NSSize(width: 300, height: 208))
    image.lockFocus()
    NSColor(calibratedRed: 0.98, green: 0.96, blue: 0.89, alpha: 1).setFill()
    NSBezierPath(rect: NSRect(x: 0, y: 0, width: 300, height: 208)).fill()
    let style = NSMutableParagraphStyle(); style.lineBreakMode = .byTruncatingTail
    let isLink = URL(string: text.trimmingCharacters(in: .whitespacesAndNewlines)).map { ["http", "https"].contains($0.scheme?.lowercased() ?? "") } ?? false
    let title = isLink ? L("LINK") : L("TEXT")
    (title as NSString).draw(at: NSPoint(x: 20, y: 168), withAttributes: [.font: NSFont.systemFont(ofSize: 16, weight: .bold), .foregroundColor: NSColor(calibratedRed: 0.1, green: 0.45, blue: 0.4, alpha: 1)])
    (String(text.prefix(500)) as NSString).draw(with: NSRect(x: 20, y: 16, width: 260, height: 136), options: [.usesLineFragmentOrigin, .truncatesLastVisibleLine], attributes: [.font: NSFont.systemFont(ofSize: 23), .foregroundColor: NSColor(calibratedWhite: 0.16, alpha: 1), .paragraphStyle: style])
    image.unlockFocus()
    return image
}
/// Screen recordings, as macOS saves them.
func isRecording(_ url: URL) -> Bool {
    ["mov", "mp4"].contains(url.pathExtension.lowercased())
}

/// The default size covers a card at twice its size in points, as on a
/// Retina screen, and no more: every photo on the line keeps one in memory.
func makeThumbnail(_ url: URL, maxPixels: Int = Int(320 * Layout.size.scale)) -> NSImage? {
    if isRecording(url) { return firstFrame(url, maxPixels: maxPixels) }
    guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
    let options: [CFString: Any] = [
        kCGImageSourceCreateThumbnailFromImageAlways: true,
        kCGImageSourceCreateThumbnailWithTransform: true,
        kCGImageSourceThumbnailMaxPixelSize: maxPixels,
    ]
    guard let cg = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else { return nil }
    return NSImage(cgImage: cg, size: NSSize(width: cg.width, height: cg.height))
}

/// A recording shows its first frame.
private func firstFrame(_ url: URL, maxPixels: Int) -> NSImage? {
    let generator = AVAssetImageGenerator(asset: AVURLAsset(url: url))
    generator.appliesPreferredTrackTransform = true
    generator.maximumSize = CGSize(width: maxPixels, height: maxPixels)
    guard let cg = try? generator.copyCGImage(at: .zero, actualTime: nil) else { return nil }
    return NSImage(cgImage: cg, size: NSSize(width: cg.width, height: cg.height))
}
