/// A model an agent's one-shot run may be asked for, by the name its CLI
/// takes, and the efforts its CLI accepts for it.
public struct AgentModel: Identifiable, Hashable, Sendable {
  public let id: String
  /// Empty for an agent with no effort flag.
  let efforts: [String]

  init(_ id: String, efforts: [String] = []) {
    self.id = id
    self.efforts = efforts
  }
}
