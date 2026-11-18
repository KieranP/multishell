/// A row of the CLI Activity table: one command's runs over the range.
public struct DebugCLIActivityRow: Sendable, Equatable, Identifiable {
  public let command: String
  let tally: CLIExecutionTally
  let slowestLocation: DebugLocation?

  public var id: String { command }
}
