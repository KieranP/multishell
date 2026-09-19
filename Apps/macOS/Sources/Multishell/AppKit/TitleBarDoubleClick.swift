import AppKit
import SwiftUI

/// Makes a view respond to a double-click the way a title bar does, the
/// header rows standing in for a hidden one. Follows the system setting.
struct TitleBarDoubleClick: ViewModifier {
  func body(content: Content) -> some View {
    content
      .contentShape(.rect)
      .simultaneousGesture(
        TapGesture(count: 2).onEnded {
          Self.perform(on: NSApp.keyWindow)
        })
  }

  static func perform(on window: NSWindow?) {
    guard let window else { return }
    // The key lives in the global domain, which `standard` searches.
    switch UserDefaults.standard.string(forKey: "AppleActionOnDoubleClick") {
    case "Minimize": window.miniaturize(nil)
    case "None": break
    default: window.zoom(nil)
    }
  }
}

extension View {
  func titleBarDoubleClick() -> some View {
    modifier(TitleBarDoubleClick())
  }
}
