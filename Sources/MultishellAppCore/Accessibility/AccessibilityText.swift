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
  /// by name and under its parent. No times: they are read later than built,
  /// and cost a clock each.
  public static func workers(_ workers: [Worker]) -> String {
    let displayNames = Dictionary(workers.map { ($0.id, $0.displayName) }) { first, _ in first }
    let spokenWorkers = workers.nested.map { nested in
      let worker = nested.worker
      let spokenName = [worker.displayName, worker.occurrenceText].compactMap { $0 }
        .joined(separator: " ")
      guard nested.depth > 0, let parentName = worker.parentID.flatMap({ displayNames[$0] }) else {
        return spokenName
      }
      return t("spoken.worker-under", spokenName, parentName)
    }
    return ([workers.countText] + spokenWorkers).joined(separator: ", ")
  }

  /// Which pane of a split, on a sidebar row and a board card alike.
  static func panePosition(_ position: PanePosition) -> String {
    t("spoken.pane-position", position.number, position.count)
  }
}
