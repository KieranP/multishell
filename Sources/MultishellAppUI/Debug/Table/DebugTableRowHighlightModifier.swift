import MultishellCore
import SwiftUI

/// A debug table row filled faintly while the pointer is over it, so the
/// numbers at its right end read against the name at its left.
struct DebugTableRowHighlightModifier: ViewModifier {
  let theme: Theme

  @State private var isHovered = false

  func body(content: Content) -> some View {
    content
      .background(isHovered ? theme.faintFill : .clear)
      .onHover { isHovered = $0 }
  }
}
