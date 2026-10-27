import MultishellCore
import SwiftUI

/// A word under a glyph while the pointer rests on it, drawn in the area's
/// theme where `.help`'s is the system's grey box and comes a second later.
struct HoverTooltip: ViewModifier {
  /// Long enough that sweeping across the tabs shows none.
  private static let delay: Duration = .milliseconds(400)
  /// Between the anchor's foot and the tooltip's top.
  private static let gap: Double = 4

  let text: String
  let palette: AreaPalette
  let metrics: UIMetrics

  @State private var isShown = false
  @State private var pendingShow: Task<Void, Never>?

  private var label: some View {
    Text(text)
      .font(metrics.font(size: metrics.caption, weight: .medium))
      .foregroundStyle(palette.text)
      .fixedSize()
      .padding(.horizontal, 8)
      .padding(.vertical, 4)
      .background(
        palette.background,
        in: RoundedRectangle(cornerRadius: UIMetrics.rowCornerRadius),
      )
      .overlay {
        RoundedRectangle(cornerRadius: UIMetrics.rowCornerRadius)
          .strokeBorder(palette.border, lineWidth: UIMetrics.hairlineThickness)
      }
      .shadow(color: .black.opacity(0.25), radius: 6, y: 2)
  }

  func body(content: Content) -> some View {
    content
      .onHover { isHovering in
        pendingShow?.cancel()
        guard isHovering else {
          isShown = false
          return
        }
        pendingShow = Task {
          try? await Task.sleep(for: Self.delay)
          if !Task.isCancelled { isShown = true }
        }
      }
      // Hung from a zero-height line at the anchor's foot, so it floats below
      // the anchor whatever the overlay's alignment does with guides.
      .overlay(alignment: .bottom) {
        Color.clear
          .frame(height: 0)
          .overlay(alignment: .top) {
            if isShown {
              label
                .padding(.top, Self.gap)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
                .transition(.opacity)
            }
          }
      }
      .animation(.easeOut(duration: 0.12), value: isShown)
  }
}
