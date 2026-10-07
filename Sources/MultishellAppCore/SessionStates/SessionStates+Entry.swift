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
    var note: SessionNote?
    var roster = WorkerRoster()
    /// What a worker's report put the dot over, remembered once, for the
    /// last worker out to put back; `nil` while the agent's own state shows.
    var displaced: Displaced?
    /// Who raised the prompts on screen, since only that thread's next tool
    /// call, or its end, says its own was answered.
    var promptRaisers: Set<PromptRaiser> = []
    /// Whether the agent whose last Stop this turn heard takes a turn when
    /// its workers end.
    var resumesAfterWorkers = false
    /// A turn of the agent's is running, or an end has woken one, so a Stop
    /// is coming that pays whatever is owed.
    var isTurnUnderway = false

    enum Displaced: Equatable {
      case nothing
      case done
      /// A Done the agent's own Stop owes, which its later reports do not
      /// take back: only the last worker out settles it.
      case owedDone
      /// The failure's own note and age, put back with it: the prompt that
      /// covered it rewrote both, and a card reads a note only for its state.
      case failed(SessionNote?, since: Date?)

      var isFailure: Bool {
        if case .failed = self { return true }
        return false
      }
    }

    enum PromptRaiser: Hashable {
      case agent
      case worker(String)

      var workerID: String? {
        if case .worker(let id) = self { return id }
        return nil
      }
    }

    var isEmpty: Bool {
      state == nil && pid == nil && since == nil && note == nil && roster.isEmpty
        && displaced == nil && promptRaisers.isEmpty && !isTurnUnderway
    }

    /// A report about a worker recorded on the roster, an unnamed end taking the
    /// oldest place with a prompt up. Returns the place touched.
    @discardableResult
    mutating func record(_ report: WorkerReport) -> WorkerRoster.Place {
      roster.record(report, asking: Set(promptRaisers.compactMap(\.workerID)))
    }

    /// Remembers what a worker's report is about to stand over, once. A
    /// failure is displaced only by a prompt, never by mere work.
    mutating func rememberDisplaced(byPrompt: Bool) {
      guard displaced == nil else { return }
      switch state {
      case nil: displaced = .nothing
      // A worker heard after a resuming agent's Stop was out at it, its start
      // landing late, so that Stop's Done is owed to the turn its end wakes.
      case .done: displaced = resumesAfterWorkers ? .owedDone : .done
      case .failed where byPrompt: displaced = .failed(note, since: since)
      default: break
      }
    }

    /// The turn is over, however it ended: nothing out, displaced or asked.
    mutating func settleTurn() {
      roster = WorkerRoster()
      clearDisplaced()
      resumesAfterWorkers = false
      isTurnUnderway = false
    }

    /// Nothing displaced, and nothing asked that it was holding.
    mutating func clearDisplaced() {
      displaced = nil
      promptRaisers = []
    }

    /// A new turn: what the last one owed or asked goes, and so does a worker
    /// no Stop saw out, which an interrupt may have killed without a word.
    mutating func startTurn() {
      let kept = roster.keepingOutAtStop()
      settleTurn()
      roster = kept
    }

    /// One prompt answered, `true` when no other is asking. A shared place
    /// answers nothing, being any of them; see Docs/design/agents.md.
    mutating func answer(_ raiser: PromptRaiser, sharedPlace: Bool = false) -> Bool {
      guard !sharedPlace else { return false }
      promptRaisers.remove(raiser)
      return promptRaisers.isEmpty
    }
  }
}
