import AppKit
import Testing

@testable import MultishellAppCore
@testable import MultishellAppUI

@Suite @MainActor
struct MacPlatformMenuTests {
  /// SwiftUI sets a menu's ticks from its delegate as the menu opens, not as
  /// the value behind them changes.
  private final class TickingAsItOpens: NSObject, NSMenuDelegate {
    func menuNeedsUpdate(_ menu: NSMenu) {
      menu.items.first?.state = .on
    }
  }

  @Test func aTickTheMenuSetsAsItOpensIsReadAsTicked() {
    let delegate = TickingAsItOpens()
    let view = NSMenu(title: "View")
    view.delegate = delegate
    view.addItem(NSMenuItem(title: "Show Hidden Files", action: nil, keyEquivalent: ""))
    let bar = NSMenu()
    let top = NSMenuItem(title: "View", action: nil, keyEquivalent: "")
    top.submenu = view
    bar.addItem(top)

    let items = MacPlatform.items(in: bar, under: [])

    #expect(items.map(\.isChecked) == [true])
  }
}
