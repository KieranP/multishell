import MultishellCore

/// What a screen reader says for the rows and tabs drawn by hand, neither
/// being a system list that would describe itself.
public enum AccessibilityText {
  /// The mark a row draws, said where it adds something: a tab whose title
  /// is already the agent's name would otherwise say it twice.
  static func spokenAgent(_ agentName: String?, title: String) -> [String] {
    guard let agentName, agentName != title else { return [] }
    return [t("spoken.named", agentName, t("spoken.agent"))]
  }

  /// The workers chip on a sidebar row or a board card: how many, then each
  /// by kind. No times: they are read later than built, and cost a clock each.
  public static func workers(_ workers: [Worker]) -> String {
    let named = workers.map { worker in
      [worker.displayName, worker.occurrenceText].compactMap { $0 }.joined(separator: " ")
    }
    return ([workers.countText] + named).joined(separator: ", ")
  }

  /// Which pane of a split, on a sidebar row and a board card alike.
  static func panePosition(_ position: PanePosition) -> String {
    t("spoken.pane-position", position.number, position.count)
  }
}
