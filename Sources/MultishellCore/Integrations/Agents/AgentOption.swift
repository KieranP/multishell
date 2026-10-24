/// A flag and the value after it, which some agents take only behind a
/// prefix: Codex sets effort through `-c model_reasoning_effort=<level>`.
struct AgentOption: Hashable, Sendable {
  let name: String
  var valuePrefix = ""

  func arguments(_ value: String) -> [String] {
    [name, valuePrefix + value]
  }
}
