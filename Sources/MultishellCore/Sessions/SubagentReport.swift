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

  /// Display only, so cut rather than dropped, as the message is.
  static let maximumTypeLength = 64

  public var id: String
  /// What the agent calls the kind: `Explore`, `Plan`, a custom agent's name.
  public var type: String?
  public var phase: Phase

  public init(id: String, type: String? = nil, phase: Phase) {
    self.id = id
    self.type = type
    self.phase = phase
  }

  /// Any process may write a line, so the reader bounds both strings. An id
  /// past the report's limit is no worker's and counts as an unnamed one.
  public init(from decoder: any Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    let id = try container.decode(String.self, forKey: .id)
    self.id = id.count <= SessionStateReport.maximumIdentifierLength ? id : Self.anonymousID
    type = try container.decodeIfPresent(String.self, forKey: .type).map {
      $0.count > Self.maximumTypeLength ? $0.prefix(Self.maximumTypeLength) + "…" : $0
    }
    phase = try container.decode(Phase.self, forKey: .phase)
  }
}
