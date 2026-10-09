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
  static let maximumDescriptionLength = 200

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
  /// The name the agent shows for this worker, where it gave one. Set only
  /// through the inits, which cut it, as they cut the description.
  public private(set) var name: String?
  /// What the worker was launched to do, as the agent shows it.
  public private(set) var description: String?
  /// Set on an end that was a kill or a failure, which the list draws as
  /// failed for a while; see Docs/design/agents.md.
  public internal(set) var hasFailed: Bool?
  /// Set on the worker's own stop while it is still listed, which a finished
  /// worker sends before it leaves and a killed one never; see agents.md.
  public internal(set) var isPaused: Bool?

  enum CodingKeys: String, CodingKey {
    case id, type, phase, name, description
    case wakesAgent = "wakes"
    case isBackgroundShell = "shell"
    case parentID = "parent"
    case hasFailed = "failed"
    case isPaused = "paused"
  }

  /// Bounds every string both ways, since any process may write a line. An id
  /// past the report's limit is no worker's and counts as an unnamed one.
  public init(
    id: String, type: String? = nil, phase: Phase, wakesAgent: Bool? = nil,
    isBackgroundShell: Bool? = nil, parentID: String? = nil, name: String? = nil,
    description: String? = nil, hasFailed: Bool? = nil, isPaused: Bool? = nil
  ) {
    self.id = id.count <= SessionStateReport.maximumIdentifierLength ? id : Self.anonymousID
    self.type = type?.truncated(to: Self.maximumTypeLength)
    self.phase = phase
    self.wakesAgent = wakesAgent
    self.isBackgroundShell = isBackgroundShell
    self.parentID = SessionStateReport.boundedIdentifier(parentID)
    self.name = name?.truncated(to: Self.maximumNameLength)
    self.description = description?.truncated(to: Self.maximumDescriptionLength)
    self.hasFailed = hasFailed
    self.isPaused = isPaused
  }

  public init(from decoder: any Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    self.init(
      id: try container.decode(String.self, forKey: .id),
      type: try container.decodeIfPresent(String.self, forKey: .type),
      phase: try container.decode(Phase.self, forKey: .phase),
      wakesAgent: try container.decodeIfPresent(Bool.self, forKey: .wakesAgent),
      isBackgroundShell: try container.decodeIfPresent(Bool.self, forKey: .isBackgroundShell),
      parentID: try container.decodeIfPresent(String.self, forKey: .parentID),
      name: try container.decodeIfPresent(String.self, forKey: .name),
      description: try container.decodeIfPresent(String.self, forKey: .description),
      hasFailed: try container.decodeIfPresent(Bool.self, forKey: .hasFailed),
      isPaused: try container.decodeIfPresent(Bool.self, forKey: .isPaused))
  }
}
