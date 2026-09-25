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
    /// The workers the agent still has out.
    var roster = SubagentRoster()
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

      var workerID: String? {
        if case .worker(let id) = self { return id }
        return nil
      }
    }

    var isEmpty: Bool {
      state == nil && pid == nil && since == nil && note == nil && roster.isEmpty
        && displaced == nil && waitingRaisers.isEmpty && !awaitingResume
    }

    /// A report about a worker recorded on the roster, an unnamed end taking the
    /// oldest place with a prompt up. Returns the place touched.
    @discardableResult
    mutating func record(_ report: SubagentReport) -> SubagentRoster.Place {
      roster.record(report, asking: Set(waitingRaisers.compactMap(\.workerID)))
    }

    /// Remembers what a worker's report is about to stand over, once. A
    /// failure is displaced only by a prompt, never by mere work.
    mutating func rememberDisplaced(byPrompt: Bool) {
      guard displaced == nil else { return }
      switch state {
      case nil: displaced = .nothing
      case .done: displaced = .done
      case .failed where byPrompt: displaced = .failed(note, since: since)
      default: break
      }
    }

    /// The turn is over, however it ended: nothing out, displaced or asked.
    mutating func settleTurn() {
      roster = SubagentRoster()
      displaced = nil
      waitingRaisers = []
      awaitingResume = false
    }

    /// One prompt answered, `true` when no other is asking. A shared place
    /// answers nothing, being any of them; see Docs/design/agents.md.
    mutating func answer(_ raiser: Raiser, sharedPlace: Bool = false) -> Bool {
      guard !sharedPlace else { return false }
      waitingRaisers.remove(raiser)
      return waitingRaisers.isEmpty
    }
  }
}
