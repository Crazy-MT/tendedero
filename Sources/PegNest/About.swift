import AppKit
import SwiftUI

@MainActor
final class About {
    static let shared = About()
    func show(privacy: Bool = false) {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
        let license = Bundle.main.url(forResource: "LICENSE", withExtension: "txt").flatMap { try? String(contentsOf: $0, encoding: .utf8) } ?? ""
        let policy = L("Clipboard history stays on this Mac. No accounts, analytics or developer servers. Recording is optional and can be paused. Clear history permanently deletes private copies; external screenshot originals are preserved. Privacy markers are respected, but unmarked passwords can be recorded. macOS Universal Clipboard may sync your current clipboard according to your system settings.")
        TextPreview.shared.show("\(L("PegNest")) · \(version)\n\n\(policy)\n\n\(L("Independent modification of Tendedero by Alejandro Buján. The original author does not endorse this app."))\nhttps://github.com/alejandrobujan/tendedero\n\n\(license)")
    }
}


struct ControlsView: View {
    @ObservedObject var line: Line
    @State var enabled: Bool
    let onRecording: () -> Bool
    let onFolder: () -> Void
    let onShow: () -> Void
    let onPrivacy: () -> Void
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 14) {
                Image(nsImage: NSApp.applicationIconImage).resizable().frame(width: 64, height: 64)
                VStack(alignment: .leading, spacing: 5) {
                    Text(L("PegNest")).font(.title.bold())
                    Text(L("Hang your screenshots and clipboard within reach.")).foregroundStyle(.secondary)
                }
            }
            Divider()
            Text(L("Keep copied text, links and images on this Mac. Click a hanging card to copy it again.")).fixedSize(horizontal: false, vertical: true)
            Button(enabled ? L("Pause clipboard recording") : L("Enable clipboard recording")) { enabled = onRecording() }
                .buttonStyle(.borderedProminent)
            HStack {
                Button(L("Choose screenshot folder…"), action: onFolder)
                Button(L("Show line"), action: onShow)
            }
            Text(L("Rest the pointer in the menu bar or press Control–Option–T. Double click text to read it in full.")).font(.callout).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            HStack {
                Text(String(format: L("%d items in history"), line.liveCount)).foregroundStyle(.secondary)
                Spacer()
                Button(L("Clear history")) { line.clear() }
            }
            Button(L("Privacy & Open Source"), action: onPrivacy).buttonStyle(.link)
        }.padding(28).frame(width: 500, height: 420)
    }
}
