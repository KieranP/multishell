/// How an agent is handed the task it starts on, after its flags. Each case
/// keeps a task opening with a dash from being read as a flag.
public enum AgentTaskArgument: Hashable, Sendable {
  /// The prompt operand, behind `--`.
  case operand
  /// An option taking the task as its value, joined by `=`.
  case option(String)

  public func arguments(for task: String) -> [String] {
    let line = Self.oneLine(task)
    return switch self {
    case .operand: ["--", line]
    case .option(let name): ["\(name)=\(line)"]
    }
  }

  /// tcsh refuses a line break inside quotes and inside a quoted variable
  /// read alike, so a task reaches every shell as one line.
  static func oneLine(_ task: String) -> String {
    task.split(whereSeparator: \.isNewline).joined(separator: " ")
  }
}
