import Foundation
import MultishellCore

/// When and at what cost each worktree's `git status` was last read, and the
/// pace those readings are judged by; see Docs/design/worktrees.md.
public struct StatusReadLog: Sendable {
  var pace = StatusPollPace.standard

  private var reads: [Worktree.ID: (at: ContinuousClock.Instant, took: Duration)] = [:]
  private var generation = 0

  public init() {}

  public var isEmpty: Bool { reads.isEmpty }

  /// Whether this worktree is due a read, by what the last one cost.
  func isDue(_ id: Worktree.ID, at now: ContinuousClock.Instant) -> Bool {
    pace.isDue(lastRead: reads[id]?.at, took: reads[id]?.took, at: now)
  }

  /// A read's cost, kept so the poll can leave a slow checkout alone for a
  /// while. Only pass what badged a row: a reading thrown away paces nothing.
  public mutating func remember(_ costs: [Worktree.ID: Duration]) {
    let finished = ContinuousClock.now
    for (id, took) in costs { reads[id] = (finished, took) }
  }

  public mutating func forget(_ gone: Set<Worktree.ID>) {
    reads = reads.filter { !gone.contains($0.key) }
  }

  /// A read may begin. The value goes back to `stillCounts` once git answered.
  func currentGeneration() -> Int { generation }

  func stillCounts(_ generation: Int) -> Bool { self.generation == generation }

  /// What a badge counts has changed, so every reading is worthless and every
  /// worktree is due again.
  public mutating func invalidate() {
    generation += 1
    reads.removeAll()
  }
}
