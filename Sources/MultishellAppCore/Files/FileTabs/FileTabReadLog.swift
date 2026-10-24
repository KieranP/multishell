import MultishellCore

/// Each file tab's reads: what the last one cost, which run now, which had a
/// change land meanwhile, and which hidden tabs are owed one when shown.
struct FileTabReadLog {
  /// A re-read waits ten times what the last cost, so an agent rewriting a
  /// file in bursts takes at most a tenth of a core.
  private static let costMultiple = 10

  private var lastCost: [FileTab.ID: Duration] = [:]
  /// Each re-show of a tab highlights the same read's rows again, so one counts.
  private var lastHighlightCost: [FileTab.ID: Duration] = [:]
  private var lastFinished: [FileTab.ID: ContinuousClock.Instant] = [:]
  private var reading: Set<FileTab.ID> = []
  private var askedAgain: Set<FileTab.ID> = []
  private(set) var owed: Set<FileTab.ID> = []
  /// What each tab's file looked like when last checked, `nil` for gone.
  private var signatures: [FileTab.ID: FileSignature?] = [:]

  func isReading(_ id: FileTab.ID) -> Bool { reading.contains(id) }

  /// `.some(nil)` for a file seen gone, `nil` for one never looked at.
  func signature(of id: FileTab.ID) -> FileSignature?? { signatures[id] }

  mutating func note(_ signature: FileSignature?, of id: FileTab.ID) {
    signatures[id] = .some(signature)
  }

  /// `nil` for a tab never read, which is due now.
  func nextDue(_ id: FileTab.ID) -> ContinuousClock.Instant? {
    guard let finished = lastFinished[id] else { return nil }
    return finished + ((lastCost[id] ?? .zero) + (lastHighlightCost[id] ?? .zero))
      * Self.costMultiple
  }

  mutating func begin(_ id: FileTab.ID) {
    reading.insert(id)
    owed.remove(id)
  }

  /// Whether a change landed during the read, which then runs once more.
  mutating func finish(_ id: FileTab.ID, cost: Duration) -> Bool {
    reading.remove(id)
    lastCost[id] = cost
    lastHighlightCost[id] = nil
    lastFinished[id] = .now
    return askedAgain.remove(id) != nil
  }

  /// The view's highlighting of the rows a read made, part of that read's
  /// cost: a whole-file parse can cost more than the diff.
  mutating func noteHighlightCost(_ cost: Duration, of id: FileTab.ID) {
    guard lastFinished[id] != nil else { return }
    lastHighlightCost[id] = cost
  }

  /// A change during a read is read again after it, never dropped.
  mutating func askAgain(_ id: FileTab.ID) { askedAgain.insert(id) }

  mutating func owe(_ id: FileTab.ID) { owed.insert(id) }

  /// A tab's reads forgotten, as a change of what it diffs wants: the cost of
  /// a diff the tab no longer shows says nothing about the next.
  mutating func forgetPace(of id: FileTab.ID) {
    lastCost[id] = nil
    lastHighlightCost[id] = nil
    lastFinished[id] = nil
  }

  mutating func keep(only ids: Set<FileTab.ID>) {
    lastCost = lastCost.filter { ids.contains($0.key) }
    lastHighlightCost = lastHighlightCost.filter { ids.contains($0.key) }
    lastFinished = lastFinished.filter { ids.contains($0.key) }
    reading.formIntersection(ids)
    askedAgain.formIntersection(ids)
    owed.formIntersection(ids)
    signatures = signatures.filter { ids.contains($0.key) }
  }
}
