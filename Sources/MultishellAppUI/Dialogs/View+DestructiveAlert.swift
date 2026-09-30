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
