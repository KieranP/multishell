import MultishellAppCore
import MultishellCore
import MultishellGitKit
import SwiftUI

/// The glyphs at a worktree row's right end. Several views rather than one,
/// so the row's own spacing sits between them.
struct WorktreeRowBadges: View {
  let operation: WorktreeOperation?
  let autoRename: AutoRenameState?
  let isLocked: Bool
  let standing: BranchStanding
  let status: WorktreeStatus?
  /// Already zero where the pane rows list them; see `SidebarWorktree`.
  let terminalCount: Int
  let theme: Theme
  let metrics: UIMetrics
  let showModifiedFiles: () -> Void
  let clearAutoRenameFailure: () -> Void
  let servicesPopover: () -> ServicesPopover

  var body: some View {
    if let operation {
      if operation.isRunning {
        runningGlyph(help: operation.title)
      } else {
        failureGlyph(saying: operation.title)
      }
    }
    switch autoRename {
    case .running:
      runningGlyph(help: t("sidebar.auto-renaming"))

    case .failed(let message):
      Button(action: clearAutoRenameFailure) {
        failureGlyph(saying: t("sidebar.auto-rename-failed", message))
          .contentShape(.rect)
      }
      .buttonStyle(.plain)

    case nil:
      EmptyView()
    }
    if isLocked {
      Image(systemName: "lock.fill")
        .font(metrics.font(size: metrics.small))
        .foregroundStyle(theme.projectsPanel.textTertiary)
        .help(t("sidebar.locked"))
        .accessibilityLabel(t("sidebar.locked"))
    }
    if standing.showsMergedBadge(with: status) {
      Image(systemName: "arrow.triangle.merge")
        .font(metrics.font(size: metrics.badge))
        .foregroundStyle(theme.mergedColor)
        .help(standing.mergeState.tooltip)
        .accessibilityLabel(standing.mergeState.tooltip)
    }
    // Git changes and the services sit left of the terminal count, so the count
    // stays at the row's right edge and lines up with rows that have neither.
    if let status = WorktreeStatus.badged(status) {
      Button(action: showModifiedFiles) {
        GitStatusBadge(
          status: status,
          theme: theme,
          metrics: metrics,
          tint: theme.projectsPanel.textSecondary,
        )
        .contentShape(.rect)
      }
      .buttonStyle(.plain)
    }
    if standing.services.showsAnything {
      WorktreeRowServicesButton(
        services: standing.services,
        theme: theme,
        metrics: metrics,
        popover: servicesPopover,
      )
    }
    if terminalCount > 0 {
      Text("\(terminalCount)")
        .font(metrics.font(size: metrics.badge, weight: .semibold))
        .monospacedDigit()
        .foregroundStyle(theme.projectsPanel.textSecondary)
        .padding(.horizontal, 6)
        .padding(.vertical, 1)
        .background(theme.projectsPanel.fill, in: Capsule())
        .help(t("count.terminals", terminalCount))
    }
  }

  /// One look for anything under way on the row, a stage or an Auto Rename.
  private func runningGlyph(help: String) -> some View {
    ProgressView()
      .controlSize(.mini)
      .help(help)
  }

  /// One look for anything that failed on the row, so a warning reads one way.
  private func failureGlyph(saying text: String) -> some View {
    Image(systemName: "exclamationmark.triangle.fill")
      .font(metrics.font(size: metrics.badge))
      .foregroundStyle(theme.failureColor)
      .help(text)
      .accessibilityLabel(text)
  }
}
