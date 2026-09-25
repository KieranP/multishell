import Foundation
import MultishellCore

/// One worker an agent has out, as the app knows it from the reports about
/// it. Runtime only, kept by `SessionStates`; see Docs/design/agents.md.
public struct Subagent: Identifiable, Equatable, Sendable {
  public let id: String
  /// What the agent calls the kind, `nil` for a worker an older helper
  /// counted without naming.
  public let type: String?
  /// When it started. Handed in by `stampChanges`, never read from a clock.
  public var since: Date?
  /// How many workers share this roster place. Above one only where an agent
  /// names a worker without an id; see Docs/design/agents.md.
  var occurrences = 1
  /// Set on a shell the agent backgrounded, whose exit is its end.
  var pid: Int32?

  public init(id: String, type: String?, since: Date? = nil) {
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

  /// Ids given to workers an older helper counted without naming, so its
  /// `-1` takes one of those and never a named one.
  static let anonymousPrefix = "anonymous:"
  var isAnonymous: Bool { id.hasPrefix(Self.anonymousPrefix) }

  public var displayName: String {
    type ?? (pid == nil ? t("subagent.unnamed") : t("subagent.background-shell"))
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
