import Foundation

/// How a read of many files splits its git runs.
extension WorktreeGit {
  /// Paths one command names at once, well under the argument list's limit.
  static let pathsPerCommand = 500
  /// Runs at once, each one core's work: on 12 cores, 8 was fastest and 16 slower.
  public static let runsAtOnce = max(2, ProcessInfo.processInfo.activeProcessorCount * 2 / 3)
}
