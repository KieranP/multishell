/// A row of the Git commands table: one command's runs over the range.
public struct DebugGitCommand: Sendable, Equatable, Identifiable {
  public let command: String
  public let tally: GitCommandTally
  public let slowestLocation: DebugLocation?

  public var id: String { command }
}
