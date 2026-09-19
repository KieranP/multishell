import Foundation
import MultishellCore

extension SessionStates {
  /// Everything known about one key, so a prune is one dictionary operation.
  /// `since` and `note` outlive a state that went nil: `stampChanges` owns them.
  struct Entry: Equatable, Sendable {
    var state: SessionState?
    /// The process behind a Working or Waiting state, when the report said.
    var pid: Int32?
    /// When the state last changed. Handed in, never read from a clock.
    var since: Date?
    /// What the last report said beyond its state.
    var note: SessionNote?
    /// The workers the agent still has out, in the order they started; see
    /// Docs/design/agents.md.
    var workers: [Subagent] = []
    /// What a worker's report put the dot over, remembered once, for the
    /// last worker out to put back; `nil` while the agent's own state shows.
    var displaced: Displaced?
    /// Who raised the prompts on screen, since only that thread's next tool
    /// call, or its end, says its own was answered.
    var waitingRaisers: Set<Raiser> = []

    enum Displaced: Equatable {
      case nothing
      case done
      /// A Done the agent's own Stop owes, which its later reports do not
      /// take back: only the last worker out pays it.
      case stop
      /// The failure's own note, put back with it: the prompt that covered
      /// it rewrote the note, and a card reads one only for its own state.
      case failed(SessionNote?)

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
    /// under it when it did. Copilot names workers alike, so such a place
    /// gives no way to tell which of them reported.
    struct Place {
      var id: String
      var isShared = false
    }

    var isEmpty: Bool {
      state == nil && pid == nil && since == nil && note == nil && workers.isEmpty
        && displaced == nil && waitingRaisers.isEmpty
    }

    /// A start or a tool call puts a worker on the roster, its end takes it off.
    /// Returns the roster place touched, which is what raises and answers.
    @discardableResult
    mutating func keep(_ report: SubagentReport) -> Place {
      let isAnonymous = report.id == SubagentReport.anonymousID
      switch report.phase {
      case .ended:
        guard let index = endingPlace(for: report) else { return Place(id: report.id) }
        let place = Place(id: workers[index].id, isShared: workers[index].occurrences > 1)
        if workers[index].occurrences > 1 {
          workers[index].occurrences -= 1
        } else {
          workers.remove(at: index)
        }
        return place
      case .working where isAnonymous:
        // A tool call names no worker either, so it is one already out, and
        // only a start puts another unnamed place on the roster.
        guard let index = workers.lastIndex(where: \.isAnonymous) else {
          let id = Subagent.anonymousPrefix + UUID().uuidString
          workers.append(Subagent(id: id, type: report.type))
          return Place(id: id)
        }
        return Place(id: workers[index].id, isShared: workers[index].occurrences > 1)
      case .started, .working:
        let id = isAnonymous ? Subagent.anonymousPrefix + UUID().uuidString : report.id
        guard let index = workers.firstIndex(where: { $0.id == id }) else {
          workers.append(Subagent(id: id, type: report.type))
          return Place(id: id)
        }
        // A tool call from one already out says nothing; a second start under
        // its id is a second worker an agent named without an id.
        if report.phase == .started { workers[index].occurrences += 1 }
        return Place(id: id, isShared: workers[index].occurrences > 1)
      }
    }

    /// Which place an end takes. A named one takes its own and nothing where
    /// it is not out. An unnamed end is one worker gone whichever it was, so
    /// it takes one that is asking before one that is not, and the oldest
    /// place of any kind rather than nothing: a roster left a worker over
    /// holds the agent's Done for the rest of the turn.
    private func endingPlace(for report: SubagentReport) -> Int? {
      guard report.id == SubagentReport.anonymousID else {
        return workers.firstIndex { $0.id == report.id }
      }
      let asking = workers.lastIndex { $0.isAnonymous && waitingRaisers.contains(.worker($0.id)) }
      return asking ?? workers.lastIndex(where: \.isAnonymous) ?? workers.indices.first
    }

    /// Remembers what a worker's report is about to stand over, once. A
    /// failure is displaced only by a prompt, never by mere work.
    mutating func rememberDisplaced(byPrompt: Bool) {
      guard displaced == nil else { return }
      switch state {
      case nil: displaced = .nothing
      case .done: displaced = .done
      case .error where byPrompt: displaced = .failed(note)
      default: break
      }
    }

    /// The turn is over, however it ended: nothing out, displaced or asked.
    mutating func settleTurn() {
      workers = []
      displaced = nil
      waitingRaisers = []
    }

    /// One thread's prompt answered. `true` when no other is still asking,
    /// so the dot may move on. A report from a place several workers share
    /// answers nothing: it may be from any of them, and the prompt is still
    /// on screen. See Docs/design/agents.md.
    mutating func answered(_ raiser: Raiser, sharedPlace: Bool = false) -> Bool {
      guard !sharedPlace else { return false }
      waitingRaisers.remove(raiser)
      return waitingRaisers.isEmpty
    }
  }
}
