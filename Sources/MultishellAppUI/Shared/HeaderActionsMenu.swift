import MultishellCore
import SwiftUI

/// The `ellipsis.circle` menu a worktree's header and a file tab's bar end
/// with, its items the caller's.
struct HeaderActionsMenu<Items: View>: View {
  let help: String
  let palette: AreaPalette
  @ViewBuilder let items: () -> Items

  var body: some View {
    HeaderGlyphMenu(symbol: "ellipsis.circle", help: help, palette: palette, items: items)
  }
}
