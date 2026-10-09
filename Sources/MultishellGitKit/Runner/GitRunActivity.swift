/// What the run log held when drained: the runs started and finished since
/// the drain before, and how many are still going.
public struct GitRunActivity: Sendable, Equatable {
  public static let empty = Self(startedCount: 0, runningCount: 0, finishedRuns: [])

  public let startedCount: Int
  public let runningCount: Int
  public let finishedRuns: [GitRun]
}
