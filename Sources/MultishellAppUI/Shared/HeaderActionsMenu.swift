import MultishellCore
import SwiftUI

/// The `ellipsis.circle` menu a worktree's header and a file tab's bar end
/// with, its items the caller's.
struct HeaderActionsMenu<Items: View>: View {
  let help: String
  let palette: AreaPalette
  @ViewBuilder let items: () -> Items

  var body: some View {
    // Drawn by SwiftUI, and so in the theme, where a borderless menu's AppKit
    // button drew the glyph in the system's grey. Painted to be hit-tested.
    Menu(content: items) {
      HeaderGlyph(symbol: "ellipsis.circle")
        .foregroundStyle(palette.textSecondary)
        .background(palette.background)
        .contentShape(.rect)
    }
    .glyphMenuStyle()
    .fixedSize()
    .help(help)
    .accessibilityLabel(help)
  }
}
