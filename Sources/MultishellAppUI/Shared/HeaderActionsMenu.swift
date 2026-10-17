import MultishellCore
import SwiftUI

/// The `ellipsis.circle` menu a worktree's header and a file tab's bar end
/// with, its items the caller's.
struct HeaderActionsMenu<Items: View>: View {
  let help: String
  let theme: Theme
  @ViewBuilder let items: () -> Items

  var body: some View {
    Menu(content: items) {
      HeaderGlyph(symbol: "ellipsis.circle")
        .contentShape(.rect)
    }
    .menuStyle(.borderlessButton)
    .menuIndicator(.hidden)
    .fixedSize()
    .foregroundStyle(theme.textSecondary)
    .help(help)
    .accessibilityLabel(help)
  }
}
