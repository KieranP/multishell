import SwiftUI

extension View {
  /// A menu drawn as its label alone. Not `.borderlessButton`, an AppKit button that
  /// keeps one image of the label at its own tint; see Docs/design/tabs-and-groups.md.
  func glyphMenuStyle() -> some View {
    menuStyle(.button)
      .buttonStyle(.plain)
      .menuIndicator(.hidden)
  }
}
