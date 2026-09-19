import Foundation

/// One subagent's change, riding on a report. The app keeps the roster, a
/// hook being a fresh process with nothing to remember; see Docs/design/agents.md.
public struct SubagentReport: Codable, Hashable, Sendable {
  public enum Phase: String, Codable, Hashable, Sendable, CaseIterable {
    case started
    /// A tool call inside it, the one sign a worker gives between its start
    /// and its end: how one whose start went unseen joins the roster.
    case working
    case ended
  }

  /// The id a report carries when the helper counted a worker without
  /// naming one, from a build before workers had names.
  public static let anonymousID = ""

  public var id: String
  /// What the agent calls the kind: `Explore`, `Plan`, a custom agent's name.
  public var type: String?
  public var phase: Phase

  public init(id: String, type: String? = nil, phase: Phase) {
    self.id = id
    self.type = type
    self.phase = phase
  }
}
