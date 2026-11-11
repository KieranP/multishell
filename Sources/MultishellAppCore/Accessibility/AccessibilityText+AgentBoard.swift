import Foundation
import MultishellCore
import MultishellGitKit

/// What a screen reader says for the Agents board, which is drawn by hand
/// like the sidebar rows beside it.
extension AccessibilityText {
  /// State and place first, then the title, the occupant the card no longer
  /// shows, and the rest of the card; see Docs/design/appearance/window-chrome.md.
  public static func card(_ card: AgentBoardCard, at now: Date) -> String {
    var parts = [card.state.shownState.displayName]
    parts.append(t("spoken.named", card.projectName, card.worktreeName))
    if let status = WorktreeStatus.badged(card.status) { parts.append(status.summary) }
    parts.append(card.title)
    parts.append(
      t(
        "spoken.named",
        card.occupant.name,
        card.occupant.isAgent ? t("spoken.agent") : t("spoken.shell"),
      )
    )
    if let position = card.position { parts.append(panePosition(position)) }
    if !card.workers.isEmpty { parts.append(card.workers.countText) }
    if let elapsed = card.elapsed(at: now) { parts.append(t("spoken.elapsed", elapsed)) }
    if let message = card.message { parts.append(message) }
    return parts.joined(separator: ", ")
  }

  /// The sidebar's Agents entry, which carries the counts.
  public static func agentsRow(_ counts: [AgentBoardLaneCount]) -> String {
    let said = counts.map { t("spoken.lane-count", $0.count, $0.lane.title(inSentence: true)) }
    let tail = said.isEmpty ? [t("spoken.nothing-running")] : said
    return ([t("label.agents")] + tail).joined(separator: ", ")
  }
}
