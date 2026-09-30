import Foundation
import MultishellCore

/// One worker an agent has out, as the app knows it from the reports about
/// it. Runtime only, kept by `SessionStates`; see Docs/design/agents.md.
public struct Subagent: Identifiable, Equatable, Sendable {
  public let id: String
  /// What the agent calls the kind, `nil` where no report said.
  var type: String?
  /// When it started. Handed in by `stampChanges`, never read from a clock.
  var since: Date?
  /// How many workers share this roster place. Above one only where an agent
  /// names a worker without an id; see Docs/design/agents.md.
  var occurrences = 1
  /// Set on a shell the agent backgrounded, whose exit is its end.
  var pid: Int32?
  /// A shell a Stop named by the agent's own id, which the next Stop's list
  /// ends by leaving it out.
  var isListedShell = false
  /// Put on by a Stop's list before its start landed, so that start is
  /// this worker's own rather than a second one under its id.
  var awaitsStart = false
  /// On the roster when a Stop was held for it, so a background worker and
  /// not one an interrupt could have killed without a word.
  var outAtStop = false
  /// Reported since the last held Stop, so a Stop that finds it silent does
  /// not vouch for it: its end may have been lost.
  var heardSinceStop = true

  var isBackgroundShell: Bool { pid != nil || isListedShell }

  init(id: String, type: String?, since: Date? = nil) {
    self.id = id
    self.type = type
    self.since = since
  }

  init(id: String, type: String?, pid: Int32) {
    self.init(id: id, type: type)
    self.pid = pid
  }

  static let shellPrefix = "shell:"

  /// The place every worker started past the roster limit shares.
  static let overflowID = "overflow:"

  /// Ids given to workers reported without one, so an unnamed end takes one of
  /// those and never a named one.
  static let anonymousPrefix = "anonymous:"
  var isAnonymous: Bool { id.hasPrefix(Self.anonymousPrefix) }

  public var displayName: String {
    type ?? (isBackgroundShell ? t("subagent.background-shell") : t("subagent.unnamed"))
  }

  /// How many workers this place stands for, where that is more than one.
  /// `nil` is drawn as nothing rather than as a 1 beside every name.
  public var occurrenceText: String? {
    occurrences > 1 ? t("subagent.occurrences", occurrences) : nil
  }

  public func elapsed(at now: Date) -> String? {
    ElapsedText.short(since: since, now: now)
  }
}
