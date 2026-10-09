import MultishellCore

extension [Worker] {
  /// Subagents, background shells and failed workers counted apart.
  public var countText: String {
    let shells = filter(\.isBackgroundShell).workerCount
    let subagents = workerCount - shells
    return [
      subagents > 0 ? t("count.subagents", subagents) : nil,
      shells > 0 ? t("count.background-shells", shells) : nil,
      failedCount > 0 ? t("count.failed-workers", failedCount) : nil,
    ].compactMap(\.self).joined(separator: ", ")
  }

  /// What is out, or with nothing out the failed rows still drawn.
  public var chipCount: Int { workerCount > 0 ? workerCount : failedCount }

  public var chipState: SessionState { workerCount > 0 ? .running : .failed }
}
