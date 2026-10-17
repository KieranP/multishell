import MultishellCore
import SwiftUI

/// What every tab in a strip shares around its content: insets, the shown
/// tab's fill, the hairline, the whole area hit, a click and a middle click.
struct TabFaceModifier: ViewModifier {
  let isShown: Bool
  /// What the shown tab is filled with: the content under it, so the two join.
  let shownFill: Color
  let theme: Theme
  let activate: () -> Void
  let close: () -> Void

  func body(content: Content) -> some View {
    content
      .padding(.horizontal, UIMetrics.tabSideInset)
      .frame(maxWidth: .infinity, maxHeight: .infinity)
      .background(isShown ? shownFill : .clear)
      .overlay(alignment: .trailing) {
        if !isShown {
          theme.tabBar.border.frame(width: UIMetrics.hairlineThickness).padding(.vertical, 8)
        }
      }
      .contentShape(.rect)
      .onTapGesture(perform: activate)
      // Every tab strip closes on a middle click, the active one or not.
      .onMiddleClick(perform: close)
  }
}
