import AppKit

@MainActor
final class Markup {
    static let shared = Markup()
    var onSaved: (URL) -> Void = { _ in }
    func edit(_ url: URL) {
        // Preview exposes its public editor without relying on a private sharing service identifier.
        NSWorkspace.shared.open(url)
    }
}
