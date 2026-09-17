import Foundation
import MultishellCore

/// One worker an agent has out, as the app knows it from the reports about
/// it. Runtime only, kept by `SessionStates`; see docs/design/agents.md.
public struct Subagent: Identifiable, Equatable, Sendable {
  public let id: String
  /// What the agent calls the kind, `nil` for a worker an older helper
  /// counted without naming.
  public let type: String?
  /// When it started. Handed in by `stampChanges`, never read from a clock.
  public var since: Date?
  /// How many workers share this roster place. Above one only where an agent
  /// names a worker without an id; see docs/design/agents.md.
  var occurrences = 1

  public init(id: String, type: String?, since: Date? = nil) {
    self.id = id
    self.type = type
    self.since = since
  }

  /// Ids given to workers an older helper counted without naming, so its
  /// `-1` takes one of those and never a named one.
  static let anonymousPrefix = "anonymous:"
  var isAnonymous: Bool { id.hasPrefix(Self.anonymousPrefix) }

  public var displayName: String { type ?? t("subagent.unnamed") }

  /// How many workers this place stands for, where that is more than one.
  /// `nil` is drawn as nothing rather than as a 1 beside every name.
  public var occurrenceText: String? {
    occurrences > 1 ? t("subagent.occurrences", occurrences) : nil
  }

  public func elapsed(at now: Date) -> String? {
    guard let since else { return nil }
    return ElapsedText.short(since: since, now: max(now, since))
  }
}

extension [Subagent] {
  /// How many workers these places stand for, which is more than the number
  /// of places where an agent named two workers alike; see agents.md.
  public var workerCount: Int { reduce(0) { $0 + $1.occurrences } }
}
