import MultishellCore

/// When and at what cost each worktree's `git status` was last read, the pace those readings
/// are judged by, and which reads are in flight; see worktrees/watching-and-status-reads.md.
struct StatusReadLog: Sendable {
  struct Ticket: Sendable {
    fileprivate let generation: Int
    fileprivate let serial: Int
    fileprivate let ids: [Worktree.ID]
  }

  var pace = StatusReadPace.standard

  private var reads = LastReads()
  private var generation = 0
  private var inFlightSerial: [Worktree.ID: Int] = [:]
  private var landedSerial: [Worktree.ID: Int] = [:]
  /// A forgotten worktree's reads still running, which count for nothing:
  /// one re-made at the path is another checkout.
  private var forgottenWhileReading: [Worktree.ID: Int] = [:]
  private var askedAgain: Set<Worktree.ID> = []
  private var serial = 0

  /// Whether no reading is kept to pace by, for the tests.
  var hasNoReadings: Bool { reads.isEmpty }

  /// Whether this worktree is due a read, by what the last one cost.
  func isDue(_ id: Worktree.ID, at now: ContinuousClock.Instant) -> Bool {
    pace.isDue(lastRead: reads[id]?.at, duration: reads[id]?.duration, at: now)
  }

  /// When this worktree may next be read, which may have passed; nil where it
  /// was never read.
  func nextDue(_ id: Worktree.ID) -> ContinuousClock.Instant? {
    pace.nextDue(lastRead: reads[id]?.at, duration: reads[id]?.duration)
  }

  /// A read's cost, kept so the next read can leave a slow checkout alone for a
  /// while. Only pass what badged a row: a reading thrown away paces nothing.
  mutating func remember(_ costs: [Worktree.ID: Duration]) {
    reads.remember(costs)
  }

  mutating func forget(_ gone: some Sequence<Worktree.ID>) {
    reads.forget(gone)
    askedAgain.subtract(gone)
    for id in gone {
      landedSerial[id] = nil
      if inFlightSerial[id] != nil { forgottenWhileReading[id] = serial }
    }
  }

  /// Whether a read that still counts is under way for this worktree.
  func isReading(_ id: Worktree.ID) -> Bool { inFlightSerial[id] != nil }

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
    for id in ids { inFlightSerial[id] = serial }
    return Ticket(generation: generation, serial: serial, ids: ids)
  }

  /// Git answered for the `answered` rows: every row goes free, bar any a later
  /// read has taken, and the result is the answers no later read landed over.
  mutating func finish(_ ticket: Ticket, answered: Set<Worktree.ID>) -> Set<Worktree.ID> {
    for id in ticket.ids where inFlightSerial[id] == ticket.serial { inFlightSerial[id] = nil }
    guard ticket.generation == generation else { return [] }
    let counted = ticket.ids.filter { id in
      answered.contains(id)
        && ticket.serial
          > max(landedSerial[id, default: 0], forgottenWhileReading[id, default: 0])
    }
    for id in counted { landedSerial[id] = ticket.serial }
    for id in ticket.ids where inFlightSerial[id] == nil { forgottenWhileReading[id] = nil }
    return Set(counted)
  }

  /// Rows of a finished read a later one has answered, the newer badge in.
  func overtaken(_ ticket: Ticket) -> Set<Worktree.ID> {
    Set(ticket.ids.filter { landedSerial[$0, default: 0] > ticket.serial })
  }

  /// What a badge counts has changed, so every reading is worthless and every
  /// worktree is due again, a read in flight included.
  mutating func invalidate() {
    generation += 1
    reads.removeAll()
    inFlightSerial.removeAll()
    forgottenWhileReading.removeAll()
  }
}
