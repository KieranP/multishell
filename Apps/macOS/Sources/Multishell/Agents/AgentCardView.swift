import MultishellAppCore
import MultishellCore
import SwiftUI

/// One pane's card: who is at the prompt, how long it has been there, what
/// the tab is called, where it is, and the last thing it said.
///
/// No line of terminal output: neither engine hands scrollback to the core,
/// so there is none to draw.
struct AgentCardView: View {
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
      top
      Text(card.title)
        .font(.system(size: metrics.secondary))
        .foregroundStyle(theme.textPrimary)
        .lineLimit(2)
        .fixedSize(horizontal: false, vertical: true)
      place
      if let message = card.message {
        AgentCardMessage(text: message, theme: theme, metrics: metrics)
      }
      if let status = card.status, !status.isClean {
        AgentCardChanges(status: status, theme: theme, metrics: metrics)
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
    .contextMenu { AgentCardActions(model: model, card: card) }
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(AccessibilityText.card(card, at: now))
    .accessibilityAddTraits(.isButton)
  }

  /// The dot, who is at the prompt, and how long they have been in this
  /// column. A shell names itself in the monospaced face an agent does not,
  /// so a glance separates the two without a second badge.
  private var top: some View {
    HStack(spacing: 6) {
      Circle()
        .fill(theme.color(for: card.state ?? .idle))
        .frame(width: 7, height: 7)
      Text(card.occupant.name)
        .font(
          card.occupant.isAgent
            ? .system(size: metrics.caption, weight: .semibold)
            : .system(size: metrics.badge, design: .monospaced)
        )
        .foregroundStyle(card.occupant.isAgent ? theme.textPrimary : theme.textSecondary)
        .lineLimit(1)
      Spacer(minLength: 4)
      if let elapsed = card.elapsed(at: now) {
        Text(elapsed)
          .font(.system(size: metrics.badge, design: .monospaced))
          .monospacedDigit()
          .foregroundStyle(theme.textTertiary)
      }
    }
  }

  private var place: some View {
    HStack(spacing: 4) {
      Text(card.projectName)
        .foregroundStyle(theme.textSecondary)
        .lineLimit(1)
      Image(systemName: "chevron.right")
        .font(.system(size: metrics.badge - 3, weight: .bold))
        .foregroundStyle(theme.textTertiary)
      Text(card.worktreeName)
        .font(.system(size: metrics.badge, design: .monospaced))
        .foregroundStyle(theme.ansiRGB[6].color)
        .lineLimit(1)
        .truncationMode(.middle)
    }
    .font(.system(size: metrics.badge))
  }
}
