import MultishellCore

extension AppModel {
  /// Every command the CLIs ran over the range, in the order the table's header picked.
  public func debugCLIActivityRows(
    for range: DebugRange,
    sortedBy sort: DebugTableSort<DebugCLIActivityColumn>,
  ) -> [DebugCLIActivityRow] {
    var tallies: [String: CLIExecutionTally] = [:]
    for sample in shownDebugSnapshot.history.samples(in: range) {
      for (command, tally) in sample.cliExecutions {
        tallies[command, default: CLIExecutionTally()].merge(tally)
      }
    }
    let worktreesByPath = worktreesByStandardizedPath()
    let rows = tallies.map { command, tally in
      DebugCLIActivityRow(
        command: command,
        tally: tally,
        slowestLocation: tally.slowestDirectory.map { directory in
          debugLocation(ofDirectory: directory, in: worktreesByPath)
        },
      )
    }
    return sort.ordered(rows)
  }
}
