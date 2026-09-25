import Foundation
import MultishellCore

extension SessionStates {
  /// Everything known about one key, so a prune is one dictionary operation.
  /// `since` and `note` outlive a state that went nil: `stampChanges` owns them.
  struct Entry: Equatable, Sendable {
    var state: SessionState?
    /// The process behind a Working or Waiting state, when the report said.
    var pid: Int32?
    /// The Working is the shell's report of a command started, not an agent's.
    var workingIsShellCommand = false
    /// When the state last changed. Handed in, never read from a clock.
    var since: Date?
    /// What the last report said beyond its state.
    var note: SessionNote?
    /// The workers the agent still has out, in the order they started; see
    /// Docs/design/agents.md.
    var subagents: [Subagent] = []
    /// What a worker's report put the dot over, remembered once, for the
    /// last worker out to put back; `nil` while the agent's own state shows.
    var displaced: Displaced?
    /// Who raised the prompts on screen, since only that thread's next tool
    /// call, or its end, says its own was answered.
    var waitingRaisers: Set<Raiser> = []
    /// Whether the agent whose Stop is owed takes a turn when its workers
    /// end. Read only while `displaced` is `.stop`.
    var stopResumes = false
    /// The last worker is out and that turn has not reported yet.
    var awaitingResume = false
    /// Workers past the roster limit by id, all under the one overflow place,
    /// so a tool call is told from a new worker and a stray end from their own.
    var folded: [String: Int] = [:]

    enum Displaced: Equatable {
      case nothing
      case done
      /// A Done the agent's own Stop owes, which its later reports do not
      /// take back: only the last worker out pays it.
      case stop
      /// The failure's own note and age, put back with it: the prompt that
      /// covered it rewrote both, and a card reads a note only for its state.
      case failed(SessionNote?, since: Date?)

      var isFailure: Bool {
        if case .failed = self { return true }
        return false
      }
    }

    enum Raiser: Hashable {
      case agent
      case worker(String)
    }

    /// A roster place a report touched, and whether more than one worker was
    /// under it: a start repeated under one id makes which reported unknowable.
    struct Place {
      var id: String
      var isShared = false
    }

    /// How many ids the overflow place tells apart; a worker past that is dropped.
    static let foldLimit = 1024

    var isEmpty: Bool {
      state == nil && pid == nil && since == nil && note == nil && subagents.isEmpty
        && displaced == nil && waitingRaisers.isEmpty && !awaitingResume && folded.isEmpty
    }

    /// A start or a tool call puts a worker on the roster, its end takes it off.
    /// Returns the roster place touched, which is what raises and answers.
    @discardableResult
    mutating func keep(_ report: SubagentReport) -> Place {
      let isAnonymous = report.id == SubagentReport.anonymousID
      switch report.phase {
      case .ended:
        if let id = foldedID(endedBy: report) { return unfold(id) }
        guard let index = endingPlace(for: report) else { return Place(id: report.id) }
        let place = Place(id: subagents[index].id, isShared: subagents[index].occurrences > 1)
        if subagents[index].occurrences > 1 {
          subagents[index].occurrences -= 1
        } else {
          subagents.remove(at: index)
        }
        return place
      case .working where isAnonymous:
        // A tool call names no worker either, so it is one already out, and
        // only a start puts another unnamed place on the roster.
        if let index = subagents.lastIndex(where: \.isAnonymous) {
          return Place(id: subagents[index].id, isShared: subagents[index].occurrences > 1)
        }
        if foldedAnonymousID != nil { return overflowPlace }
        return add(Subagent(id: Subagent.anonymousPrefix + UUID().uuidString, type: report.type))
      case .started, .working:
        let id = isAnonymous ? Subagent.anonymousPrefix + UUID().uuidString : report.id
        guard let index = subagents.firstIndex(where: { $0.id == id }) else {
          guard folded[id] != nil else { return add(Subagent(id: id, type: report.type)) }
          if report.phase == .started { _ = fold(id) }
          return overflowPlace
        }
        // A tool call from one already out says nothing; a second start under
        // its id is a second worker an agent named without an id.
        if report.phase == .started { subagents[index].occurrences += 1 }
        return Place(id: id, isShared: subagents[index].occurrences > 1)
      }
    }

    /// Which place an end takes: a named one its own, an unnamed one the
    /// oldest asking. Never nothing, or a leftover holds Done all turn.
    private func endingPlace(for report: SubagentReport) -> Int? {
      guard report.id == SubagentReport.anonymousID else {
        return subagents.firstIndex { $0.id == report.id }
      }
      let asking = subagents.lastIndex { $0.isAnonymous && waitingRaisers.contains(.worker($0.id)) }
      // A background shell's end is its exit, never a hook's.
      return asking ?? subagents.lastIndex(where: \.isAnonymous) ?? firstNamedPlace
    }

    private var firstNamedPlace: Int? {
      subagents.firstIndex { $0.pid == nil && $0.id != Subagent.overflowID }
    }

    /// The folded worker an end takes, in `endingPlace`'s order: an unnamed
    /// end takes an unnamed one first, and any only where no named place is left.
    private func foldedID(endedBy report: SubagentReport) -> String? {
      guard report.id == SubagentReport.anonymousID else {
        return folded[report.id] == nil ? nil : report.id
      }
      guard !subagents.contains(where: \.isAnonymous) else { return nil }
      return foldedAnonymousID ?? (firstNamedPlace == nil ? folded.keys.first : nil)
    }

    private var foldedAnonymousID: String? {
      folded.keys.first { $0.hasPrefix(Subagent.anonymousPrefix) }
    }

    private var overflowIndex: Int? {
      subagents.firstIndex { $0.id == Subagent.overflowID }
    }

    private var overflowPlace: Place {
      Place(
        id: Subagent.overflowID,
        isShared: overflowIndex.map { subagents[$0].occurrences > 1 } ?? false)
    }

    /// One place per pid, however many Stops name it.
    mutating func keepShells(_ pids: [Int32]) {
      var kept = Set(subagents.compactMap(\.pid))
      for pid in pids where kept.insert(pid).inserted {
        add(Subagent(id: Subagent.shellPrefix + String(pid), type: nil, pid: pid))
      }
    }

    /// Past the limit a worker shares one overflow place, so none still out is
    /// dropped. A shell is, its pid having nowhere to go in a shared place.
    @discardableResult
    private mutating func add(_ worker: Subagent) -> Place {
      let placed = subagents.count - (overflowIndex == nil ? 0 : 1)
      guard placed >= SessionStateReport.rosterLimit else {
        subagents.append(worker)
        return Place(id: worker.id)
      }
      guard worker.pid == nil, fold(worker.id) else { return Place(id: worker.id) }
      return overflowPlace
    }

    /// `false` for a new id once the overflow place holds `foldLimit` of them.
    private mutating func fold(_ id: String) -> Bool {
      guard folded[id] != nil || folded.count < Self.foldLimit else { return false }
      folded[id, default: 0] += 1
      if let overflow = overflowIndex {
        subagents[overflow].occurrences += 1
      } else {
        subagents.append(Subagent(id: Subagent.overflowID, type: nil))
      }
      return true
    }

    /// Takes a worker off wherever it is, every start under its id included.
    mutating func forgetSubagent(_ id: String) {
      subagents.removeAll { $0.id == id }
      for _ in 0..<(folded[id] ?? 0) { unfold(id) }
    }

    @discardableResult
    private mutating func unfold(_ id: String) -> Place {
      let place = overflowPlace
      folded[id] = folded[id].flatMap { $0 > 1 ? $0 - 1 : nil }
      if let overflow = overflowIndex {
        if subagents[overflow].occurrences > 1 {
          subagents[overflow].occurrences -= 1
        } else {
          subagents.remove(at: overflow)
        }
      }
      return place
    }

    /// Remembers what a worker's report is about to stand over, once. A
    /// failure is displaced only by a prompt, never by mere work.
    mutating func rememberDisplaced(byPrompt: Bool) {
      guard displaced == nil else { return }
      switch state {
      case nil: displaced = .nothing
      case .done: displaced = .done
      case .error where byPrompt: displaced = .failed(note, since: since)
      default: break
      }
    }

    /// The turn is over, however it ended: nothing out, displaced or asked.
    mutating func settleTurn() {
      subagents = []
      folded = [:]
      displaced = nil
      waitingRaisers = []
      awaitingResume = false
    }

    /// One prompt answered, `true` when no other is asking. A shared place
    /// answers nothing, being any of them; see Docs/design/agents.md.
    mutating func answered(_ raiser: Raiser, sharedPlace: Bool = false) -> Bool {
      guard !sharedPlace else { return false }
      waitingRaisers.remove(raiser)
      return waitingRaisers.isEmpty
    }
  }
}
