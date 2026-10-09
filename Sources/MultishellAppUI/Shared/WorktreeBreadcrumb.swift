import MultishellCore
import SwiftUI

/// Project › worktree, which the detail header and a board card both lead
/// with. No stack of its own: the parts take the caller's spacing and priorities.
struct WorktreeBreadcrumb: View {
  /// The header keeps both names whole and gives way at the path after them;
  /// a card is smaller and cuts the worktree's name in the middle.
  enum Style { case header, card }

  let projectName: String
  let worktreeName: String
  let style: Style
  let theme: Theme
  let metrics: UIMetrics

  var body: some View {
    Text(projectName)
      .font(projectFont)
      .foregroundStyle(style == .header ? theme.textPrimary : theme.textSecondary)
      .lineLimit(1)
      .layoutPriority(namePriority)
    Image(systemName: "chevron.right")
      .font(.system(size: chevronSize, weight: .bold))
      .foregroundStyle(theme.textTertiary)
      .accessibilityHidden(true)
    Text(worktreeName)
      .font(worktreeFont)
      .foregroundStyle(theme.worktreeNameColor)
      .lineLimit(1)
      .truncationMode(style == .header ? .tail : .middle)
      .layoutPriority(namePriority)
  }

  private var projectFont: Font {
    switch style {
    case .header: .system(size: metrics.bodySize, weight: .semibold)
    case .card: .system(size: metrics.badge)
    }
  }

  private var chevronSize: Double {
    switch style {
    case .header: metrics.small
    case .card: metrics.cardBreadcrumbChevronSize
    }
  }

  private var worktreeFont: Font {
    switch style {
    case .header: .system(size: metrics.monospaced, weight: .medium, design: .monospaced)
    case .card: .system(size: metrics.badge, design: .monospaced)
    }
  }

  private var namePriority: Double { style == .header ? 1 : 0 }
}
