import AppKit

@MainActor
final class TextPreview: NSObject, NSWindowDelegate {
    static let shared = TextPreview()
    private var window: NSWindow?
    func show(_ value: String) {
        window?.close()
        let scroll = NSScrollView(frame: NSRect(x: 0, y: 0, width: 640, height: 440))
        scroll.hasVerticalScroller = true
        let text = NSTextView(frame: scroll.bounds)
        text.string = value
        text.isEditable = false; text.isSelectable = true
        text.font = NSFont.systemFont(ofSize: 16)
        text.textContainerInset = NSSize(width: 24, height: 24)
        text.autoresizingMask = [.width]; text.isVerticallyResizable = true
        text.textContainer?.widthTracksTextView = true
        text.setAccessibilityLabel(L("Full text"))
        scroll.documentView = text
        let window = NSWindow(contentRect: scroll.frame, styleMask: [.titled, .closable, .resizable], backing: .buffered, defer: false)
        window.title = L("PegNest — Full text"); window.contentView = scroll
        window.isReleasedWhenClosed = false; window.delegate = self; window.center()
        self.window = window
        NSApp.activate(ignoringOtherApps: true); window.makeKeyAndOrderFront(nil)
    }
    func windowWillClose(_ notification: Notification) { window = nil }
}
