import Foundation
import MultishellCore

/// One worker an agent has out, as the app knows it from the reports about
/// it. Runtime only, kept by `SessionStates`; see Docs/design/agents.md.
public struct Worker: Identifiable, Equatable, Sendable {
  static let shellPrefix = "shell:"

  /// The place every worker started past the roster limit shares.
  static let overflowID = "overflow:"

  /// Ids given to workers reported without one, so an unnamed end takes one of
  /// those and never a named one.
  static let anonymousPrefix = "anonymous:"

  public let id: String
  /// What the agent calls the kind, `nil` where no report said.
  var type: String?
  /// The name the agent shows for it, where it gave one.
  var name: String?
  /// What it was launched to do, as the agent shows it.
  public internal(set) var description: String?
  /// The worker that launched it, `nil` for the agent's own or where no
  /// report has said yet; see Docs/design/agents.md.
  var parentID: String?
  /// When it started. Handed in by `stampChanges`, never read from a clock.
  var startedAt: Date?
  /// How many workers share this roster place. Above one only where an agent
  /// names a worker without an id; see Docs/design/agents.md.
  var occurrences = 1
  /// Set on a shell the agent backgrounded, whose exit is its end.
  var pid: Int32?
  /// A shell a launch or a Stop named by the agent's own id, which the next
  /// Stop's list ends by leaving it out.
  var isListedShell = false
  /// Put on by a Stop's list before its start landed, so that start is
  /// this worker's own rather than a second one under its id.
  var awaitsStart = false
  /// On the roster when a Stop was held for it, so a background worker and
  /// not one an interrupt could have killed without a word.
  var wasOutAtStop = false
  /// Reported since the last held Stop, so a Stop that finds it silent does
  /// not vouch for it: its end may have been lost.
  var wasHeardSinceStop = true
  /// Ended, and kept while a worker it launched is out, drawn as out as
  /// Claude draws it; see Docs/design/agents.md.
  var hasEnded = false
  /// Killed or failed, and drawn so until swept; see Docs/design/agents.md.
  var hasFailed = false
  /// When it failed. Handed in by `stampChanges`, never read from a clock.
  var failedAt: Date?
  /// Named by an agent's list of background work, which a later list ends
  /// by leaving it out.
  var wasListed = false
  /// An agent, not a shell, launched in the background by a tool call whose
  /// result named it; only Claude's hooks report one.
  var isBackgroundAgent = false
  /// Whether its last report was its own stop; a launched worker leaving the
  /// list without one was killed. See Docs/design/agents.md.
  var lastReportWasItsStop = false
  /// Paused, and the last of its own work has just ended, which wakes it, so
  /// it is kept until the next list; see Docs/design/agents.md.
  var awaitsResume = false

  var isBackgroundShell: Bool { pid != nil || isListedShell }

  var isAnonymous: Bool { id.hasPrefix(Self.anonymousPrefix) }

  /// The dot its row draws.
  public var shownState: SessionState { hasFailed ? .failed : .running }

  init(
    id: String,
    type: String?,
    name: String? = nil,
    description: String? = nil,
    parentID: String? = nil,
    startedAt: Date? = nil,
  ) {
    self.id = id
    self.type = type
    self.name = name
    self.description = description
    self.parentID = parentID
    self.startedAt = startedAt
  }

  init(id: String, type: String?, pid: Int32) {
    self.init(id: id, type: type)
    self.pid = pid
  }

  /// Drawn failed until swept, its stamp left for `stampChanges` and its
  /// starts counted as one.
  mutating func markFailed() {
    hasFailed = true
    failedAt = nil
    occurrences = 1
  }
}
