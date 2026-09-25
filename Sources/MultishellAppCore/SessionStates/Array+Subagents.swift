import MultishellCore

extension [Subagent] {
  /// How many workers these places stand for, which is more than the number
  /// of places where an agent named two workers alike; see agents.md.
  public var workerCount: Int { reduce(0) { $0 + $1.occurrences } }

  /// Subagents and background shells counted apart.
  public var countText: String {
    let shells = filter { $0.pid != nil }.workerCount
    let subagents = workerCount - shells
    return [
      subagents > 0 ? t("count.subagents", subagents) : nil,
      shells > 0 ? t("count.background-shells", shells) : nil,
    ].compactMap { $0 }.joined(separator: ", ")
  }
}
