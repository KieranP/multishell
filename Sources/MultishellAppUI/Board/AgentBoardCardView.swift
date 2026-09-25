import MultishellAppCore
import MultishellCore
import SwiftUI

/// One pane's card, read in the sidebar's order; see Docs/design/appearance.md.
/// No output on it: the engine hands the core no scrollback.
struct AgentBoardCardView: View {
  let model: AppModel
  let card: AgentBoardCard
  /// Ticks with the board, so the time in the corner stays true without
  /// every card keeping a timer.
  let now: Date
  let theme: Theme
  let metrics: UIMetrics

  @State private var isHovered = false

  var body: some View {
    VStack(alignment: .leading, spacing: 5) {
      place
      title
      if let message = card.message {
        AgentBoardCardMessage(text: message, theme: theme, metrics: metrics)
      }
    }
    .padding(.horizontal, 9)
    .padding(.vertical, 8)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(theme.cardColor, in: RoundedRectangle(cornerRadius: 6))
    .overlay {
      RoundedRectangle(cornerRadius: 6)
        .strokeBorder(
          isHovered ? theme.color(for: card.state ?? .idle) : theme.hairline,
          lineWidth: isHovered ? 1.5 : 1)
    }
    .contentShape(.rect)
    .onHover { isHovered = $0 }
    .onTapGesture { model.open(card) }
    .contextMenu { AgentBoardCardActions(model: model, card: card) }
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(AccessibilityText.card(card, at: now))
    .accessibilityAddTraits(.isButton)
  }

  /// The tab's name, with how long this pane has been in its column on the
  /// same right-hand rail the line above ends on.
  private var title: some View {
    HStack(spacing: 4) {
      if let position = card.position {
        PanePositionBadge(index: position.index, metrics: metrics, theme: theme)
      }
      Text(card.title)
        .font(.system(size: metrics.secondary))
        .foregroundStyle(theme.textPrimary)
        .lineLimit(1)
      Spacer(minLength: 6)
      if !card.subagents.isEmpty {
        SubagentChip(subagents: card.subagents, theme: theme, metrics: metrics)
      }
      if let elapsed = card.elapsed(at: now) {
        Text(elapsed)
          .font(.system(size: metrics.badge, design: .monospaced))
          .monospacedDigit()
          .foregroundStyle(theme.textTertiary)
      }
    }
  }

  /// Where the pane is, with git's verdict on the same line's right edge, so
  /// the card has one right-hand rail. The name gives way first.
  private var place: some View {
    HStack(spacing: 4) {
      PaneGlyph(
        agentID: card.occupant.agentID,
        state: card.state ?? .idle,
        ringFill: theme.cardColor,
        plainTint: theme.textSecondary,
        theme: theme,
        size: metrics.badge + 4)
      Text(card.projectName)
        .foregroundStyle(theme.textSecondary)
        .lineLimit(1)
      Image(systemName: "chevron.right")
        .font(.system(size: metrics.badge - 3, weight: .bold))
        .foregroundStyle(theme.textTertiary)
      Text(card.worktreeName)
        .font(.system(size: metrics.badge, design: .monospaced))
        .foregroundStyle(theme.worktreeNameColor)
        .lineLimit(1)
        .truncationMode(.middle)
      if let status = card.status, !status.isClean {
        Spacer(minLength: 6)
        ChangeBadge(status: status, theme: theme, size: metrics.badge, tint: theme.textTertiary)
      }
    }
    .font(.system(size: metrics.badge))
  }
}
