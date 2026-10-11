import Foundation

enum FullScreen {
    static var showLineOver: Bool {
        get { UserDefaults.standard.bool(forKey: "showOverFullScreen") }
        set { UserDefaults.standard.set(newValue, forKey: "showOverFullScreen") }
    }
}
