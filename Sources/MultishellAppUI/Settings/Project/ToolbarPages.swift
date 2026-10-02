import SwiftUI

/// Pages behind toolbar icons, the style the Settings scene uses, which SwiftUI
/// gives only to `Settings`. The same `NSTabViewController` it wraps.
struct ToolbarPages: NSViewControllerRepresentable {
  struct Page {
    let title: String
    let symbol: String
    let content: AnyView

    init(_ label: SettingsPageLabel, @ViewBuilder content: () -> some View) {
      self.title = label.title
      self.symbol = label.symbol
      self.content = AnyView(content())
    }
  }

  let pages: [Page]
  /// A value never seen before sends the window back to its first page: the
  /// controller owns the live selection, so an index binding goes stale.
  let firstPageToken: UUID

  func makeCoordinator() -> Coordinator { Coordinator() }

  func makeNSViewController(context: Context) -> NSTabViewController {
    let controller = NSTabViewController()
    controller.tabStyle = .toolbar
    for page in pages {
      let item = NSTabViewItem(viewController: NSHostingController(rootView: page.content))
      item.label = page.title
      item.image = NSImage(systemSymbolName: page.symbol, accessibilityDescription: page.title)
      controller.addTabViewItem(item)
    }
    context.coordinator.appliedToken = firstPageToken
    return controller
  }

  /// Contents are SwiftUI views observing the model, so they update
  /// themselves; only the hosting root needs refreshing on re-render.
  func updateNSViewController(_ controller: NSTabViewController, context: Context) {
    for (item, page) in zip(controller.tabViewItems, pages) {
      (item.viewController as? NSHostingController<AnyView>)?.rootView = page.content
    }
    if context.coordinator.appliedToken != firstPageToken {
      context.coordinator.appliedToken = firstPageToken
      controller.selectedTabViewItemIndex = 0
    }
  }

  final class Coordinator {
    var appliedToken: UUID?
  }
}
