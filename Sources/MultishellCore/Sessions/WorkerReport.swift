/// One worker's change, riding on a report. The app keeps the roster, a
/// hook being a fresh process with nothing to remember; see Docs/design/agents.md.
public struct WorkerReport: Codable, Hashable, Sendable {
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
  static let maximumNameLength = 64

  public internal(set) var id: String
  /// What the agent calls the kind: `Explore`, `Plan`, a custom agent's name.
  public internal(set) var type: String?
  public internal(set) var phase: Phase
  /// `false` on an end the agent takes no turn over, a cancelled worker's,
  /// so the last one out pays the Done; see Docs/design/agents.md.
  public internal(set) var wakesAgent: Bool?
  /// Set on a shell a Stop lists by the agent's own id for it, not a pid.
  public internal(set) var isBackgroundShell: Bool?
  /// The worker that launched this one, absent for the agent's own; see
  /// Docs/design/agents.md. Set only through the inits, which bound it.
  public private(set) var parentID: String?
  /// What the agent shows for this worker, a skill's name or the task's
  /// description, where it says. Set only through the inits, which cut it.
  public private(set) var name: String?

  enum CodingKeys: String, CodingKey {
    case id, type, phase, name
    case wakesAgent = "wakes"
    case isBackgroundShell = "shell"
    case parentID = "parent"
  }

  public init(
    id: String, type: String? = nil, phase: Phase, wakesAgent: Bool? = nil,
    isBackgroundShell: Bool? = nil, parentID: String? = nil, name: String? = nil
  ) {
    self.id = id
    self.type = type
    self.phase = phase
    self.wakesAgent = wakesAgent
    self.isBackgroundShell = isBackgroundShell
    self.parentID = SessionStateReport.boundedIdentifier(parentID)
    self.name = name?.truncated(to: Self.maximumNameLength)
  }

  /// Any process may write a line, so the reader bounds every string. An id
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
    parentID = SessionStateReport.boundedIdentifier(
      try container.decodeIfPresent(String.self, forKey: .parentID))
    name = try container.decodeIfPresent(String.self, forKey: .name)?
      .truncated(to: Self.maximumNameLength)
  }
}
