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

  func makeNSViewController(context: Context) -> NSTabViewController {
    let controller = NSTabViewController()
    controller.tabStyle = .toolbar
    for tab in tabs {
      let item = NSTabViewItem(viewController: NSHostingController(rootView: tab.content))
      item.label = tab.title
      item.image = NSImage(systemSymbolName: tab.symbol, accessibilityDescription: tab.title)
      controller.addTabViewItem(item)
    }
    return controller
  }

  /// Contents are SwiftUI views observing the model, so they update
  /// themselves; only the hosting root needs refreshing on re-render.
  func updateNSViewController(_ controller: NSTabViewController, context: Context) {
    for (item, tab) in zip(controller.tabViewItems, tabs) {
      (item.viewController as? NSHostingController<AnyView>)?.rootView = tab.content
    }
  }
}
