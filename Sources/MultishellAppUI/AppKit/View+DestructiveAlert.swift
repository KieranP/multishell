import AppKit
import SwiftUI

extension View {
  /// Runs `alert` as a sheet on this window while `item` is set, answering the
  /// choice pressed, or `nil` for Cancel. Clearing `item` takes it down.
  func destructiveAlert<Item: Identifiable>(
    _ item: Item?,
    alert: @escaping (Item) -> NSAlert,
    answer: @escaping (Item, Int?) -> Void
  ) -> some View {
    modifier(DestructiveAlertModifier(item: item, alert: alert, answer: answer))
  }
}

private struct DestructiveAlertModifier<Item: Identifiable>: ViewModifier {
  let item: Item?
  let alert: (Item) -> NSAlert
  let answer: (Item, Int?) -> Void

  @State private var window: NSWindow?
  @State private var shown: NSAlert?

  /// The accessor reports the window as the view lands in it, which can be
  /// after the first update, so a waiting item presents once it arrives.
  private struct Trigger: Equatable {
    let item: Item.ID?
    let hasWindow: Bool
  }

  func body(content: Content) -> some View {
    content
      .background(WindowAccessor { window = $0 })
      .onChange(of: item?.id) { _, _ in endShownSheet() }
      .task(id: Trigger(item: item?.id, hasWindow: window != nil)) {
        guard let item, let window else { return }
        let alert = alert(item)
        shown = alert
        let response = await DestructiveAlert.present(alert, in: window)
        // A second item presents before this one's sheet reports back, so
        // the reference only clears while it is still this alert's.
        if shown === alert { shown = nil }
        guard !Task.isCancelled else { return }
        answer(item, DestructiveAlert.chosen(response, of: alert.buttons.count - 1))
      }
  }

  private func endShownSheet() {
    guard let shown, let window else { return }
    self.shown = nil
    window.endSheet(shown.window, returnCode: .cancel)
  }
}
