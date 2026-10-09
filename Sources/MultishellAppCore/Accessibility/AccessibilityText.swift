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

  /// The workers chip: how many, then each by name, task, parent and failure.
  /// No times: they are read later than built, and cost a clock each.
  public static func workers(_ workers: [Worker]) -> String {
    let displayNames = Dictionary(keepingFirst: workers.map { ($0.id, $0.displayName) })
    let spokenWorkers = workers.nested.map { nested in
      let worker = nested.worker
      var spoken = [worker.displayName, worker.occurrenceText].compactMap(\.self)
        .joined(separator: " ")
      if let description = worker.description {
        spoken = t("spoken.worker-described", spoken, description)
      }
      if nested.depth > 0, let parentName = worker.parentID.flatMap({ displayNames[$0] }) {
        spoken = t("spoken.worker-under", spoken, parentName)
      }
      return worker.hasFailed ? t("spoken.worker-failed", spoken) : spoken
    }
    return ([workers.countText] + spokenWorkers).joined(separator: ", ")
  }

  /// Which pane of a split, on a sidebar row and a board card alike.
  static func panePosition(_ position: PanePosition) -> String {
    t("spoken.pane-position", position.number, position.count)
  }
}
