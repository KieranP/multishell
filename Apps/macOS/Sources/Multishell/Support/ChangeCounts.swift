import MultishellCore
import SwiftUI

/// The worktree's git badge: lines added, lines removed, files with no line
/// to show, then the unpushed arrows; see docs/design/worktrees.md.
struct ChangeCounts: View {
  let status: WorktreeStatus
  let theme: Theme
  let size: Double
  let tint: Color

  var body: some View {
    HStack(spacing: 4) {
      if status.isDirty {
        Text(t("status.insertions", status.insertions))
          .foregroundStyle(theme.ansiRGB[2].color)
        Text(t("status.deletions", status.deletions))
          .foregroundStyle(theme.ansiRGB[1].color)
      }
      if status.unscoredFiles > 0 {
        Text(t("status.unscored-badge", status.unscoredFiles))
          .foregroundStyle(theme.ansiRGB[3].color)
      }
      if status.ahead > 0 { Text("↑\(status.ahead)") }
      if status.behind > 0 { Text("↓\(status.behind)") }
    }
    .font(.system(size: size, weight: .medium))
    .monospacedDigit()
    .foregroundStyle(tint)
    // Six digits of counts are wider than the dot they replaced, and a row
    // out of room truncates the name rather than the numbers.
    .fixedSize()
    .help(status.summary)
  }
}
