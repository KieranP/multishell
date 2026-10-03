/// What the run log held when drained: the runs started and finished since
/// the drain before, and how many are still going.
public struct GitRunActivity: Sendable, Equatable {
  public let startedCount: Int
  public let runningCount: Int
  public let finishedRuns: [GitRun]

  init(startedCount: Int, runningCount: Int, finishedRuns: [GitRun]) {
    self.startedCount = startedCount
    self.runningCount = runningCount
    self.finishedRuns = finishedRuns
  }

  public static let none = GitRunActivity(startedCount: 0, runningCount: 0, finishedRuns: [])
}
