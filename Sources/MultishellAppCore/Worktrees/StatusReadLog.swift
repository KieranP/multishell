import Foundation
import MultishellCore

/// When and at what cost each worktree's `git status` was last read, and the
/// pace those readings are judged by; see Docs/design/worktrees.md.
struct StatusReadLog: Sendable {
  var pace = StatusPollPace.standard

  private var reads = ReadCosts()
  private var generation = 0
  private var reading: [Worktree.ID: Int] = [:]
  private var askedAgain: Set<Worktree.ID> = []
  private var serial = 0

  init() {}

  var isEmpty: Bool { reads.isEmpty }

  /// Whether this worktree is due a read, by what the last one cost.
  func isDue(_ id: Worktree.ID, at now: ContinuousClock.Instant) -> Bool {
    pace.isDue(lastRead: reads[id]?.at, took: reads[id]?.took, at: now)
  }

  /// A read's cost, kept so the poll can leave a slow checkout alone for a
  /// while. Only pass what badged a row: a reading thrown away paces nothing.
  mutating func remember(_ costs: [Worktree.ID: Duration]) {
    reads.remember(costs)
  }

  mutating func forget(_ gone: some Sequence<Worktree.ID>) {
    reads.forget(gone)
    askedAgain.subtract(gone)
  }

  /// Whether a read that still counts is under way for this worktree.
  func isReading(_ id: Worktree.ID) -> Bool { reading[id] != nil }

  /// A refresh asked for while this worktree is being read: the change behind
  /// it may postdate what that read sees, so it is read again once it lands.
  mutating func askAgain(_ id: Worktree.ID) { askedAgain.insert(id) }

  /// The rows of this read asked for again while it ran.
  mutating func takeAskedAgain(of ticket: Ticket) -> [Worktree.ID] {
    let again = ticket.ids.filter { askedAgain.contains($0) }
    askedAgain.subtract(again)
    return again
  }

  /// A read begins, its rows held against another until `finish`.
  mutating func begin(_ ids: [Worktree.ID]) -> Ticket {
    serial += 1
    for id in ids { reading[id] = serial }
    return Ticket(generation: generation, serial: serial, ids: ids)
  }

  /// Git answered: the rows go free, bar any a later read has taken, and the
  /// result says whether the answer still counts.
  mutating func finish(_ ticket: Ticket) -> Bool {
    for id in ticket.ids where reading[id] == ticket.serial { reading[id] = nil }
    return ticket.generation == generation
  }

  /// What a badge counts has changed, so every reading is worthless and every
  /// worktree is due again, a read in flight included.
  mutating func invalidate() {
    generation += 1
    reads.removeAll()
    reading.removeAll()
  }

  struct Ticket: Sendable {
    fileprivate let generation: Int
    fileprivate let serial: Int
    fileprivate let ids: [Worktree.ID]
  }
}
