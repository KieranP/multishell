import MultishellCore
import SwiftUI

/// What every tab in a strip shares around its content: fills, the shown tab's
/// sides, a click and a middle click. See Docs/design/tabs-and-groups/tab-strip.md.
struct TabFaceModifier: ViewModifier {
  let isShown: Bool
  /// A tab behind the shown one under the pointer; `nil` for none.
  let wash: Color?
  /// What the shown tab is filled with: the content under it, so the two join.
  let shownFill: Color
  let theme: Theme
  let activate: () -> Void
  let close: () -> Void

  private var side: some View {
    theme.tabBar.border.frame(width: UIMetrics.hairlineThickness)
  }

  func body(content: Content) -> some View {
    content
      .padding(.horizontal, UIMetrics.tabSideInset)
      .frame(maxWidth: .infinity, maxHeight: .infinity)
      // The shown tab covers the strip's bottom hairline; a wash stops short of it.
      .background(isShown ? shownFill : .clear)
      .stripPaint(wash ?? .clear)
      .overlay {
        if isShown {
          HStack(spacing: 0) {
            side
            Spacer(minLength: 0)
            side
          }
        }
      }
      .contentShape(.rect)
      .onTapGesture(perform: activate)
      // Every tab strip closes on a middle click, the active one or not.
      .onMiddleClick(perform: close)
  }
}
