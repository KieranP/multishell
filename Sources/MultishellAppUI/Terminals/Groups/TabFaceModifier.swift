import MultishellCore
import SwiftUI

/// What every tab in a strip shares around its content: insets, the shown
/// tab's fill, the hairline, the whole area hit, a click and a middle click.
struct TabFaceModifier: ViewModifier {
  let isShown: Bool
  let theme: Theme
  let activate: () -> Void
  let close: () -> Void

  func body(content: Content) -> some View {
    content
      .padding(.horizontal, UIMetrics.tabSideInset)
      .frame(maxWidth: .infinity, maxHeight: .infinity)
      .background(isShown ? theme.backgroundColor : .clear)
      .overlay(alignment: .trailing) {
        if !isShown {
          theme.hairline.frame(width: UIMetrics.hairlineThickness).padding(.vertical, 8)
        }
      }
      .contentShape(.rect)
      .onTapGesture(perform: activate)
      // Every tab strip closes on a middle click, the active one or not.
      .onMiddleClick(perform: close)
  }
}
