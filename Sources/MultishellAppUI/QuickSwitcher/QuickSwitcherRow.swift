import MultishellAppCore
import MultishellCore
import MultishellGitKit
import SwiftUI

/// One row: glyph, a split's pane number, title with the typed letters bold,
/// where it is, then its state and wait, git badge or keys.
struct QuickSwitcherRow: View {
  let item: QuickSwitcherItem
  let isSelected: Bool
  let theme: Theme
  let metrics: UIMetrics
  let choose: () -> Void
  let point: () -> Void

  private var palette: AreaPalette { theme.quickSwitcher }

  var body: some View {
    HStack(spacing: 8) {
      QuickSwitcherRowGlyph(item: item, theme: theme, metrics: metrics)
      if let position = item.position {
        PanePositionBadge(number: position.number, metrics: metrics, palette: palette)
      }
      Text(titleText)
        .foregroundStyle(palette.text)
        .lineLimit(1)
        .truncationMode(.middle)
        .layoutPriority(1)
      Text(item.location)
        .font(metrics.font(size: metrics.caption))
        .foregroundStyle(palette.textTertiary)
        .lineLimit(1)
        .truncationMode(.head)
      Spacer(minLength: 8)
      trailing
    }
    .padding(.horizontal, UIMetrics.quickSwitcherRowInset)
    .frame(height: metrics.rowHeight)
    .background(
      isSelected ? palette.color(.selectionBackground) : .clear,
      in: RoundedRectangle(cornerRadius: UIMetrics.rowCornerRadius),
    )
    .contentShape(.rect)
    .onContinuousHover { phase in
      if case .active = phase { point() }
    }
    .onTapGesture(perform: choose)
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(AccessibilityText.quickSwitcherRow(item, at: .now))
    .selectableButtonTraits(isSelected: isSelected)
    .accessibilityAction(.default, choose)
  }

  /// The typed letters bold.
  private var titleText: AttributedString {
    let plain = titleFont(weight: .regular)
    let matched = titleFont(weight: .bold)
    var text = AttributedString()
    var run = ""
    var runIsMatched = false
    // A piece per run of matched or unmatched letters, not per letter.
    for (offset, character) in item.title.enumerated() {
      let isMatched = item.titleOffsets.contains(offset)
      if isMatched != runIsMatched, !run.isEmpty {
        text += Self.piece(run, font: runIsMatched ? matched : plain)
        run = ""
      }
      run.append(character)
      runIsMatched = isMatched
    }
    if !run.isEmpty { text += Self.piece(run, font: runIsMatched ? matched : plain) }
    return text
  }

  @ViewBuilder
  private var trailing: some View {
    switch item.kind {
    case .agent, .shell:
      if let state = item.labelledState {
        HStack(spacing: 6) {
          Text(state.displayName)
            .font(metrics.font(size: metrics.caption, weight: .semibold))
            .foregroundStyle(theme.color(for: state, on: palette))
          TimelineView(.periodic(from: .now, by: 30)) { context in
            if let elapsed = item.elapsed(at: context.date) {
              Text(elapsed)
                .font(metrics.font(size: metrics.caption).monospacedDigit())
                .foregroundStyle(palette.textTertiary)
            }
          }
        }
      }

    case .worktree:
      if let status = WorktreeStatus.badged(item.status) {
        GitStatusBadge(status: status, theme: theme, metrics: metrics, tint: palette.textTertiary)
      }

    case .command:
      HStack(spacing: 6) {
        if item.isChecked {
          Image(systemName: "checkmark")
            .font(.system(size: metrics.small, weight: .semibold))
            .foregroundStyle(palette.textSecondary)
            .accessibilityHidden(true)
        }
        if let shortcut = item.shortcut {
          Text(shortcut)
            .font(metrics.font(size: metrics.caption))
            .foregroundStyle(palette.textSecondary)
        }
      }

    case .project, .fileTab, .file:
      EmptyView()
    }
  }

  private static func piece(_ text: String, font: Font) -> AttributedString {
    var piece = AttributedString(text)
    piece.font = font
    return piece
  }

  private func titleFont(weight: Font.Weight) -> Font {
    metrics.font(size: metrics.secondary, weight: weight)
  }
}
