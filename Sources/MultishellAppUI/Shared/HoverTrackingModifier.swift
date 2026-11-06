import SwiftUI

/// Keeps `isHovered` with the pointer on every move inside, not only at the edges,
/// so a button unlit by a click lights on the next move. See appearance/window-chrome.md.
struct HoverTrackingModifier: ViewModifier {
  @Binding var isHovered: Bool

  func body(content: Content) -> some View {
    content.onContinuousHover { phase in
      let isInside = if case .active = phase { true } else { false }
      // Written only on a change, as a move reports the same phase many times a second.
      if isHovered != isInside { isHovered = isInside }
    }
  }
}
