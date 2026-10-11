import MultishellGitKit

/// The newest git runs one by one, each with the sample it ended in, which
/// the tallies add up and so lose.
struct DebugGitRunLog: Sendable, Equatable {
  struct Entry: Sendable, Equatable {
    let sample: Int
    let run: GitRun
  }

  /// Bounded as the history is, a burst of status reads being hundreds.
  static let capacity = 1_000

  private(set) var entries: [Entry] = []

  mutating func append(_ runs: [GitRun], inSample sample: Int) {
    entries += runs.map { Entry(sample: sample, run: $0) }
    entries.keepLast(Self.capacity)
  }
}
