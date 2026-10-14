/// Why an agent asked for in a tab cannot start there. The launch alerts on
/// either; a command-line request is refused before its tab opens.
enum AgentStartProblem {
  case notInCatalogue
  case notInstalled
}
