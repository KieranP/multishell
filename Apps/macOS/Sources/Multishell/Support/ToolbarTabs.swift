import AppKit
import SwiftUI

/// Tabs in the toolbar-icon style the Settings scene uses.
///
/// SwiftUI gives that look only to `Settings`; an ordinary `TabView` in a
/// window draws the classic bordered tabs. `NSTabViewController` with
/// `.toolbar` is the same control the Settings scene wraps, so a project
/// window built on it matches the app-wide one exactly.
struct ToolbarTabs: NSViewControllerRepresentable {
  struct Tab {
    let title: String
    let symbol: String
    let content: AnyView

    init(_ title: String, symbol: String, @ViewBuilder content: () -> some View) {
      self.title = title
      self.symbol = symbol
      self.content = AnyView(content())
    }
  }

  let tabs: [Tab]
  /// A value never seen before sends the window back to its first tab. The
  /// controller owns the live selection, so a binding holding an index would
  /// go stale the moment the user clicked a tab and writing the old one back
  /// would read as no change. A caller mints a token rather than counting,
  /// so that asking for a reset never has to read state back.
  let firstTabToken: UUID

  func makeCoordinator() -> Coordinator { Coordinator() }

  func makeNSViewController(context: Context) -> NSTabViewController {
    let controller = NSTabViewController()
    controller.tabStyle = .toolbar
    for tab in tabs {
      let item = NSTabViewItem(viewController: NSHostingController(rootView: tab.content))
      item.label = tab.title
      item.image = NSImage(systemSymbolName: tab.symbol, accessibilityDescription: tab.title)
      controller.addTabViewItem(item)
    }
    context.coordinator.appliedToken = firstTabToken
    return controller
  }

  /// Contents are SwiftUI views observing the model, so they update
  /// themselves; only the hosting root needs refreshing on re-render.
  func updateNSViewController(_ controller: NSTabViewController, context: Context) {
    for (item, tab) in zip(controller.tabViewItems, tabs) {
      (item.viewController as? NSHostingController<AnyView>)?.rootView = tab.content
    }
    if context.coordinator.appliedToken != firstTabToken {
      context.coordinator.appliedToken = firstTabToken
      controller.selectedTabViewItemIndex = 0
    }
  }

  final class Coordinator {
    var appliedToken: UUID?
  }
}
