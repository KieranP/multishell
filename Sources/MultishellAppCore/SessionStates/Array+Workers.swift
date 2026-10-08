import MultishellCore

extension [Worker] {
  /// How many workers are out, more than the places where an agent named two
  /// alike; a failed one is drawn until swept but is not out. See agents.md.
  public var workerCount: Int { reduce(0) { $0 + ($1.hasFailed ? 0 : $1.occurrences) } }

  var failedCount: Int { filter(\.hasFailed).count }

  /// Subagents, background shells and failed workers counted apart.
  public var countText: String {
    let shells = filter(\.isBackgroundShell).workerCount
    let subagents = workerCount - shells
    return [
      subagents > 0 ? t("count.subagents", subagents) : nil,
      shells > 0 ? t("count.background-shells", shells) : nil,
      failedCount > 0 ? t("count.failed-workers", failedCount) : nil,
    ].compactMap { $0 }.joined(separator: ", ")
  }

  /// What is out, or with nothing out the failed rows still drawn.
  public var chipCount: Int { workerCount > 0 ? workerCount : failedCount }

  public var chipState: SessionState { workerCount > 0 ? .running : .failed }
}
