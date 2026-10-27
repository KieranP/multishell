/// A CircleCI phase and outcome as one status: its API's words exactly, others
/// loosely, and a word neither knows is no status; see services.md.
enum CircleCIStatusWords {
  private static let exactWords: [String: CIRunStatus] = [
    "success": .passed, "succeeded": .passed, "passed": .passed,
    "failed": .failed, "failing": .failed, "error": .failed, "errored": .failed,
    "infrastructure_fail": .failed, "timedout": .failed, "unauthorized": .failed,
    "canceled": .cancelled, "cancelled": .cancelled, "not_run": .cancelled,
    "on_hold": .onHold, "needs_approval": .onHold,
    "running": .running, "queued": .running, "not_running": .running, "blocked": .running,
    "pending": .running, "created": .running, "setup": .running, "setup-pending": .running,
  ]
  private static let looseWords: [(fragment: String, status: CIRunStatus)] = [
    ("success", .passed), ("fail", .failed), ("error", .failed), ("cancel", .cancelled),
    ("hold", .onHold), ("approval", .onHold), ("run", .running), ("pend", .running),
    ("progress", .running),
  ]

  private static let negations = ["un", "not", "no_", "non"]

  /// The phases a run has left once it stops changing: 1.11 prints `ended`.
  private static let endedPhases: Set<String> = ["ended", "completed", "finished", "done"]
  /// Said while the run's other jobs still go.
  private static let failingWord = "failing"

  /// Whether the run has ended. With no phase, a phase that is itself an
  /// outcome such as `errored`, or one neither list knows, the outcome says.
  static func isFinished(phase: String?, status: CIRunStatus) -> Bool {
    guard let phase = phase?.lowercased() else { return isSettled(status) }
    // A rerun moves the current outcome before the phase leaves `ended`.
    if endedPhases.contains(phase) { return isSettled(status) }
    guard phase != failingWord else { return false }
    let phaseStatus = Self.status(phase: phase, outcome: nil, currentOutcome: nil)
    return phaseStatus.map(isSettled) ?? isSettled(status)
  }

  private static func isSettled(_ status: CIRunStatus) -> Bool {
    status != .running && status != .onHold
  }

  /// The current outcome first, which a rerun moves; then the outcome, then
  /// the phase, which says what is still under way.
  static func status(phase: String?, outcome: String?, currentOutcome: String?) -> CIRunStatus? {
    // Each word in full before the next: a rerun's current outcome in a new
    // word still outranks the first attempt's.
    for word in [currentOutcome, outcome, phase].compactMap({ $0?.lowercased() }) {
      if let status = exactWords[word] { return status }
      // A word that denies one, `unsuccessful`, says nothing a guess could use.
      guard !negations.contains(where: word.hasPrefix) else { continue }
      if let loose = looseWords.first(where: { word.contains($0.fragment) }) { return loose.status }
    }
    return nil
  }
}
