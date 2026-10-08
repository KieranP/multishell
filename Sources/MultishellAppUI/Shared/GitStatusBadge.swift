import MultishellAppCore
import MultishellCore
import MultishellGitKit
import SwiftUI

/// The worktree's git badge: lines added, lines removed, files with no line
/// to show, then the unpushed arrows; see Docs/design/worktrees.md.
struct GitStatusBadge: View {
  let status: WorktreeStatus
  let theme: Theme
  let size: Double
  let tint: Color

  var body: some View {
    // Narrower forms only where the whole one will not fit; see
    // `GitStatusBadgeFit`. Beyond the narrowest it overflows.
    ViewThatFits(in: .horizontal) {
      counts(.full)
      counts(.withoutFiles)
      counts(.essentials)
    }
    .font(.system(size: size, weight: .medium))
    .monospacedDigit()
    .foregroundStyle(tint)
    // A row out of room truncates the name before it narrows the numbers.
    .layoutPriority(1)
    .help(status.summary)
  }

  private func counts(_ fit: GitStatusBadgeFit) -> some View {
    HStack(spacing: 4) {
      if status.isDirty {
        Text(t("status.insertions", status.insertions))
          .foregroundStyle(theme.insertionsColor)
        Text(t("status.deletions", status.deletions))
          .foregroundStyle(theme.deletionsColor)
      }
      if fit.showsFiles(of: status) {
        Text(t("status.unscored-badge", status.unscoredFiles))
          .foregroundStyle(theme.unscoredFilesColor)
      }
      if fit.showsArrows(of: status) {
        if status.ahead > 0 { Text(t("status.ahead", status.ahead)) }
        if status.behind > 0 { Text(t("status.behind", status.behind)) }
      }
    }
    .fixedSize()
  }
}
