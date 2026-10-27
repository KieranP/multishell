import MultishellAppCore
import MultishellCore
import MultishellGitKit
import SwiftUI

/// One file or folder in the Files panel, at the sidebar's row metrics: a
/// click opens a folder or the file's tab, a right-click offers the actions.
struct FilesPanelRow: View {
  /// The indent of each level, as the prototype steps it.
  private static let levelIndent: Double = 12
  /// The chevron's column, kept on a file's row so names line up.
  private static let chevronWidth: CGFloat = 9

  let model: AppModel
  let worktreeID: Worktree.ID
  let row: FileTreeRow
  /// The row's file is the tab in front.
  let isSelected: Bool
  let theme: Theme

  private var nameColor: Color {
    switch row.emphasis {
    case .faint: theme.filesPanel.textTertiary
    case .quiet: theme.filesPanel.textSecondary
    case .strong: theme.filesPanel.text
    }
  }

  var body: some View {
    let metrics = model.metrics
    HStack(spacing: 5) {
      Button(action: activate) {
        HStack(spacing: 5) {
          chevron
          Image(
            systemName: FileIcon.symbol(for: row)
          )
          .font(metrics.font(size: metrics.small))
          .foregroundStyle(theme.filesPanel.textTertiary)
          .frame(width: metrics.glyph)
          .accessibilityHidden(true)
          Text(row.name)
            .foregroundStyle(nameColor)
            .lineLimit(1)
            .truncationMode(.middle)
          if let folder = row.parentFolder {
            Text(folder)
              .font(metrics.font(size: metrics.caption))
              .foregroundStyle(theme.filesPanel.textTertiary)
              .lineLimit(1)
              .truncationMode(.head)
          }
          if row.showsChangeDot {
            Circle()
              .fill(theme.color(for: .modified).opacity(0.8))
              .frame(width: 5, height: 5)
          }
          Spacer(minLength: 0)
        }
        .contentShape(.rect)
      }
      .buttonStyle(.plain)
      if let counts = row.lineCounts, !counts.isEmpty {
        FileLineCountsText(
          counts: counts,
          theme: theme,
          size: metrics.badge,
          showsZeroSides: false,
        )
      }
    }
    .font(metrics.font(size: metrics.secondary))
    .padding(.leading, 6 + Double(row.depth) * Self.levelIndent)
    .padding(.trailing, UIMetrics.sidebarRowSideInset)
    .frame(height: metrics.paneRowHeight)
    .background(
      isSelected ? theme.color(.selectionBackground, in: .filesPanel) : .clear,
      in: RoundedRectangle(cornerRadius: UIMetrics.rowCornerRadius),
    )
    .help(row.path)
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(AccessibilityText.fileRow(row))
    .selectableButtonTraits(isSelected: isSelected)
    .accessibilityAction(.default, activate)
    .contextMenu {
      FileActions(model: model, worktreeID: worktreeID, path: row.path)
    }
  }

  @ViewBuilder
  private var chevron: some View {
    if row.isFolder {
      Image(systemName: "chevron.right")
        .font(model.metrics.font(size: model.metrics.small, weight: .semibold))
        .foregroundStyle(theme.filesPanel.textTertiary)
        .rotationEffect(row.isExpanded ? .degrees(90) : .zero)
        .frame(width: Self.chevronWidth)
        .accessibilityHidden(true)
    } else {
      Color.clear.frame(width: Self.chevronWidth)
    }
  }

  private func activate() {
    if row.isFolder {
      model.toggleFolder(row, in: worktreeID)
    } else {
      Task { await model.openFileAsTab(row.path, in: worktreeID) }
    }
  }
}
