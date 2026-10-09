import MultishellCore

extension AppModel {
  /// Every git command run over the range, the most time spent first.
  public func debugGitCommands(for range: DebugRange) -> [DebugGitCommand] {
    var tallies: [String: GitCommandTally] = [:]
    for sample in shownDebugSnapshot.history.samples(in: range) {
      for (command, tally) in sample.gitCommands {
        tallies[command, default: GitCommandTally()].merge(tally)
      }
    }
    let worktreesByPath = worktreesByStandardizedPath()
    return
      tallies
      .map { command, tally in
        DebugGitCommand(
          command: command,
          tally: tally,
          slowestLocation: tally.slowestDirectory.map { directory in
            debugLocation(ofDirectory: directory, in: worktreesByPath)
          },
        )
      }
      .sorted { ($0.tally.totalDuration, $1.command) > ($1.tally.totalDuration, $0.command) }
  }
}
