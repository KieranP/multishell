import SwiftUI

struct DestructiveAlertModifier<Item: Identifiable>: ViewModifier {
  /// The accessor reports the window as the view lands in it, which can be
  /// after the first update, so a waiting item presents once it arrives.
  private struct Trigger: Equatable {
    let item: Item.ID?
    let hasWindow: Bool
  }

  let item: Item?
  let alert: (Item) -> NSAlert
  let answer: (Item, Int?) -> Void

  @State private var window: NSWindow?
  @State private var shownAlert: NSAlert?

  func body(content: Content) -> some View {
    content
      .background(WindowAccessor { window = $0 })
      .onChange(of: item?.id) { _, _ in endShownSheet() }
      .task(id: Trigger(item: item?.id, hasWindow: window != nil)) {
        guard let item, let window else { return }
        let alert = alert(item)
        shownAlert = alert
        let response = await DestructiveAlert.present(alert, in: window)
        // A second item presents before this one's sheet reports back, so
        // the reference only clears while it is still this alert's.
        if shownAlert === alert { shownAlert = nil }
        guard !Task.isCancelled else { return }
        answer(item, DestructiveAlert.chosen(response, of: alert.buttons.count - 1))
      }
  }

  private func endShownSheet() {
    guard let shownAlert, let window else { return }
    self.shownAlert = nil
    window.endSheet(shownAlert.window, returnCode: .cancel)
  }
}
