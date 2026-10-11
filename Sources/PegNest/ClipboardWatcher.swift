import AppKit

@MainActor
final class ClipboardWatcher {
    private let pasteboard: NSPasteboard
    private let onContent: (ClipboardContent) -> Void
    private var timer: Timer?
    private var lastCount: Int
    private(set) var generation = 0
    static var isEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: "clipboardEnabled") }
        set { UserDefaults.standard.set(newValue, forKey: "clipboardEnabled") }
    }
    init(pasteboard: NSPasteboard = .general, onContent: @escaping (ClipboardContent) -> Void) {
        self.pasteboard = pasteboard; self.onContent = onContent; lastCount = pasteboard.changeCount
    }
    func start() {
        guard timer == nil else { return }
        generation += 1
        lastCount = pasteboard.changeCount
        let timer = Timer(timeInterval: 0.5, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.check() }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }
    func stop() { generation += 1; timer?.invalidate(); timer = nil }
    func check() {
        guard timer != nil else { return }
        let count = pasteboard.changeCount
        guard count != lastCount else { return }
        lastCount = count
        guard let items = pasteboard.pasteboardItems, ClipboardPolicy.accepts(types: items.map(\.types)) else { return }
        // Text takes precedence over a document's accompanying rendered image.
        if let value = pasteboard.string(forType: .string) {
            guard let value = ClipboardPolicy.text(value) else { return }
            acceptDecoded(.text(value), count: count, generation: generation)
            return
        }
        guard let type = pasteboard.availableType(from: [.png, .tiff]),
              let data = pasteboard.data(forType: type), data.count <= ClipboardPolicy.maxImageBytes,
              pasteboard.changeCount == count else { return }
        let generation = generation
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let png = ClipboardPolicy.png(from: data, type: type) else { return }
            DispatchQueue.main.async { self?.acceptDecoded(.image(png), count: count, generation: generation) }
        }
    }
    func acceptDecoded(_ content: ClipboardContent, count: Int, generation: Int) {
        guard timer != nil, self.generation == generation, pasteboard.changeCount == count else { return }
        onContent(content)
    }
}
