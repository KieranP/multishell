import Foundation
import MultishellCore

/// What a screen reader says for the Agents board, which is drawn by hand
/// like the sidebar rows beside it.
extension AccessibilityText {
  /// In the order the card draws them, with the occupant after the title,
  /// which the card itself no longer shows; see docs/design/appearance.md.
  public static func card(_ card: AgentBoardCard, at now: Date) -> String {
    var parts = [(card.state ?? .idle).displayName]
    parts.append(t("spoken.named", card.projectName, card.worktreeName))
    if let status = card.status, !status.isClean { parts.append(status.summary) }
    parts.append(card.title)
    parts.append(
      t(
        "spoken.named",
        card.occupant.name,
        card.occupant.isAgent ? t("spoken.agent") : t("spoken.shell")))
    if let position = card.position {
      parts.append(t("spoken.pane-position", position.index, position.count))
    }
    if !card.subagents.isEmpty { parts.append(t("count.subagents", card.subagents.workerCount)) }
    if let elapsed = card.elapsed(at: now) { parts.append(t("spoken.elapsed", elapsed)) }
    if let message = card.message { parts.append(message) }
    return parts.joined(separator: ", ")
  }

  /// The chip, which is what says the list is there: how many, then each by
  /// kind. No times: they are read later than they are built, and cost a clock per chip.
  public static func subagents(_ subagents: [Subagent]) -> String {
    let named = subagents.map { worker in
      [worker.displayName, worker.occurrenceText].compactMap { $0 }.joined(separator: " ")
    }
    return ([t("count.subagents", subagents.workerCount)] + named).joined(separator: ", ")
  }

  /// The sidebar's Agents entry, which carries the counts.
  public static func agentsRow(_ counts: [(lane: AgentBoardLane, count: Int)]) -> String {
    let said = counts.filter { $0.count > 0 }
      .map { t("spoken.lane-count", $0.count, $0.lane.title(inSentence: true)) }
    let tail = said.isEmpty ? [t("spoken.nothing-running")] : said
    return ([t("label.agents")] + tail).joined(separator: ", ")
  }
}
