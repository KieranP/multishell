import MultishellAppCore
import SwiftUI

/// A row taking a dragged row, measured so its delegate can tell its halves
/// apart, with a line where the dragged row will land.
struct ActionRowDropTarget: ViewModifier {
  /// Out over the row's padding and half the rule, so the gap between two rows
  /// takes a drop too, and the line lies on the rule.
  private static let reach =
    UIMetrics.settingsRowVerticalInset + UIMetrics.settingsRuleThickness / 2

  let row: Int
  /// Whether the drop held here moves the dragged row: no line in the gaps
  /// either side of it.
  let showsLine: Bool
  @Binding var drop: ActionRowDrop?
  let perform: (ActionRowDrop) -> Bool

  @State private var height = 0.0

  func body(content: Content) -> some View {
    content
      .padding(.vertical, Self.reach)
      .onGeometryChange(for: Double.self) { proxy in
        proxy.size.height
      } action: { measured in
        height = measured
      }
      .overlay(alignment: drop?.isAfter == true ? .bottom : .top) {
        if showsLine, let drop, drop.row == row {
          InsertionLine(axis: .horizontal, isAfter: drop.isAfter, color: .accentColor)
        }
      }
      .onDrop(
        of: [ActionRowTransfer.contentType],
        delegate: ActionRowDropDelegate(row: row, height: height, drop: $drop, perform: perform),
      )
      .padding(.vertical, -Self.reach)
  }
}
