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

  /// The id of a worker whose hook named none, whose id was too long, or that an
  /// older helper only counted.
  public static let anonymousID = ""

  /// Display only, so cut rather than dropped, as the message is.
  static let maximumTypeLength = 64

  public var id: String
  /// What the agent calls the kind: `Explore`, `Plan`, a custom agent's name.
  public var type: String?
  public var phase: Phase
  /// `false` on an end the agent takes no turn over, a cancelled worker's,
  /// so the last one out pays the Done; see Docs/design/agents.md.
  public var wakesAgent: Bool?
  /// Set on a shell a Stop lists by the agent's own id for it, not a pid.
  public var isBackgroundShell: Bool?

  enum CodingKeys: String, CodingKey {
    case id, type, phase
    case wakesAgent = "wakes"
    case isBackgroundShell = "shell"
  }

  public init(
    id: String, type: String? = nil, phase: Phase, wakesAgent: Bool? = nil,
    isBackgroundShell: Bool? = nil
  ) {
    self.id = id
    self.type = type
    self.phase = phase
    self.wakesAgent = wakesAgent
    self.isBackgroundShell = isBackgroundShell
  }

  /// Any process may write a line, so the reader bounds both strings. An id
  /// past the report's limit is no worker's and counts as an unnamed one.
  public init(from decoder: any Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    let id = try container.decode(String.self, forKey: .id)
    self.id = id.count <= SessionStateReport.maximumIdentifierLength ? id : Self.anonymousID
    type = try container.decodeIfPresent(String.self, forKey: .type)?
      .truncated(to: Self.maximumTypeLength)
    phase = try container.decode(Phase.self, forKey: .phase)
    wakesAgent = try container.decodeIfPresent(Bool.self, forKey: .wakesAgent)
    isBackgroundShell = try container.decodeIfPresent(Bool.self, forKey: .isBackgroundShell)
  }
}
