import SwiftUI

/// The find bar's and the quick switcher's face: a bordered panel over the
/// content, with its field in a bordered well.
extension View {
  func floatingPanel(_ background: Color, border: Color) -> some View {
    bordered(background, border: border, cornerRadius: UIMetrics.floatingPanelCornerRadius)
  }

  func floatingPanelWell(_ background: Color, border: Color) -> some View {
    bordered(background, border: border, cornerRadius: UIMetrics.floatingPanelWellCornerRadius)
  }

  private func bordered(_ background: Color, border: Color, cornerRadius: CGFloat) -> some View {
    self.background(background, in: RoundedRectangle(cornerRadius: cornerRadius))
      .overlay(RoundedRectangle(cornerRadius: cornerRadius).strokeBorder(border))
  }
}
