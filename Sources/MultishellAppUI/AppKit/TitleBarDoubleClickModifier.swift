import MultishellAppCore
import SwiftUI

/// Makes a view respond to a double-click the way a title bar does, the
/// header rows standing in for a hidden one. Follows the system setting.
struct TitleBarDoubleClickModifier: ViewModifier {
  private static func perform(on window: NSWindow?) {
    guard let window else { return }
    // The key lives in the global domain, which `standard` searches.
    let setting = UserDefaults.standard.string(forKey: "AppleActionOnDoubleClick")
    switch TitleBarDoubleClickAction(systemSetting: setting) {
    case .minimize: window.miniaturize(nil)
    case .ignore: break
    case .zoom: window.zoom(nil)
    }
  }

  func body(content: Content) -> some View {
    content
      .contentShape(.rect)
      .simultaneousGesture(
        TapGesture(count: 2).onEnded {
          Self.perform(on: NSApp.keyWindow)
        }
      )
  }
}
