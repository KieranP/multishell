import MultishellCore

/// Why an Auto Rename left the name as it was, in words for the row's
/// warning and the banner.
enum AutoRenameFailure: Error, Equatable {
  /// The agent's own words on any failed exit, unstyled and trimmed, such as
  /// that it is not signed in.
  case agentFailed(agent: String, status: Int32, said: String)
  case couldNotStart(agent: String, reason: String)
  case noName(agent: String)
  case noSharedHistory(base: String)
  case nothingToName
  case notInstalled(agent: String)
  /// The login shell has not yet said what its PATH holds.
  case stillLooking(agent: String)
  case timedOut(agent: String, seconds: Int)
  case unreadableBranch(reason: String)

  /// Past this an agent's error is a stack trace, and the tooltip a wall.
  private static let shownErrorLength = 300

  /// What the agent said after the run had gone on a while, the user perhaps
  /// elsewhere; the rest are known at the click, which the row's warning answers.
  var arrivesLate: Bool {
    switch self {
    case .agentFailed, .noName, .timedOut: true

    case .couldNotStart, .noSharedHistory, .nothingToName, .notInstalled, .stillLooking,
      .unreadableBranch:
      false
    }
  }

  var message: String {
    switch self {
    case .agentFailed(let agent, let status, let said):
      said.isEmpty
        ? t("auto-rename.agent-exited", agent, Int(status))
        : t("auto-rename.agent-said", agent, Self.ending(of: said))

    case .couldNotStart(let agent, let reason): t("auto-rename.could-not-start", agent, reason)
    case .noName(let agent): t("auto-rename.no-name", agent)
    case .noSharedHistory(let base): t("auto-rename.no-shared-history", base)
    case .nothingToName: t("auto-rename.nothing-to-name")
    case .notInstalled(let agent): t("auto-rename.not-installed", agent)
    case .stillLooking(let agent): t("auto-rename.still-looking", agent)
    case .timedOut(let agent, let seconds): t("auto-rename.timed-out", agent, seconds)
    case .unreadableBranch(let reason): t("auto-rename.unreadable-branch", reason)
    }
  }

  /// The last whole lines that fit: a CLI prints its banner first and the
  /// error last, as Codex does on standard error.
  private static func ending(of said: String) -> String {
    guard said.count > shownErrorLength else { return said }
    let tail = said.suffix(shownErrorLength)
    if said[said.index(before: tail.startIndex)].isNewline { return String(tail) }
    guard let lineStart = tail.firstIndex(where: \.isNewline),
      lineStart < tail.index(before: tail.endIndex)
    else { return String(tail) }
    return String(tail[tail.index(after: lineStart)...])
  }
}
