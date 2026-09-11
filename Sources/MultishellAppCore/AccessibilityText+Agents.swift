import Foundation
import MultishellCore

/// What a screen reader says for the Agents board, which is drawn by hand
/// like the sidebar rows beside it.
extension AccessibilityText {
  /// A card: who is at the prompt, what the pane is doing, where it is, and
  /// the last thing it said. In the order the card draws them.
  public static func card(_ card: AgentBoardCard, at now: Date) -> String {
    var parts = [
      t(
        "spoken.named",
        card.occupant.name,
        card.occupant.isAgent ? t("spoken.agent") : t("spoken.shell")),
      (card.state ?? .idle).displayName,
    ]
    if let elapsed = card.elapsed(at: now) { parts.append(t("spoken.elapsed", elapsed)) }
    parts.append(card.title)
    parts.append(t("spoken.named", card.projectName, card.worktreeName))
    if let message = card.message { parts.append(message) }
    if let status = card.status, !status.isClean { parts.append(status.summary) }
    return parts.joined(separator: ", ")
  }

  /// The sidebar's Agents entry, which carries the counts.
  public static func agentsRow(_ counts: [(lane: AgentBoardLane, count: Int)]) -> String {
    let said = counts.filter { $0.count > 0 }
      .map { t("spoken.lane-count", $0.count, $0.lane.title(inSentence: true)) }
    let tail = said.isEmpty ? [t("spoken.nothing-running")] : said
    return ([t("label.agents")] + tail).joined(separator: ", ")
  }
}
