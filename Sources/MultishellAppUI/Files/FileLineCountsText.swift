import MultishellAppCore
import MultishellCore
import SwiftUI

/// `+N −M` in the badge's colours, a zero side left out but in a footer,
/// which keeps both as the badge does; see worktrees.md.
struct FileLineCountsText: View {
  let counts: FileLineCounts
  let theme: Theme
  let size: Double
  let showsZeroSides: Bool

  var body: some View {
    HStack(spacing: 5) {
      if showsZeroSides || counts.showsInsertions {
        Text(t("status.insertions", counts.insertions)).foregroundStyle(theme.insertionsColor)
      }
      if showsZeroSides || counts.showsDeletions {
        Text(t("status.deletions", counts.deletions)).foregroundStyle(theme.deletionsColor)
      }
    }
    .font(.system(size: size, design: .monospaced))
    .fixedSize()
  }
}
