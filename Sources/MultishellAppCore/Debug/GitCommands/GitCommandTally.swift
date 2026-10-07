import Foundation
import MultishellGitKit

/// One git command's runs added up: how many, how long in all, the slowest
/// and where it ran, and the memory its runs peaked at.
public struct GitCommandTally: Sendable, Equatable {
  public internal(set) var runCount = 0
  public internal(set) var totalDuration = Duration.zero
  public internal(set) var slowestDuration = Duration.zero
  var slowestDirectory: URL?
  /// Runs whose peak was read, which the mean is over.
  var measuredRunCount = 0
  var totalPeakMemory: UInt64 = 0
  var highestPeakMemory: UInt64 = 0

  public var meanDuration: Duration {
    runCount > 0 ? totalDuration / runCount : .zero
  }

  /// `nil` where no run's peak was read, as for the one below.
  var meanPeakMemory: UInt64? {
    measuredRunCount > 0 ? totalPeakMemory / UInt64(measuredRunCount) : nil
  }

  var peakMemory: UInt64? { measuredRunCount > 0 ? highestPeakMemory : nil }

  mutating func add(_ run: GitRun) {
    let peak = run.exitUsage?.peakFootprint
    merge(
      GitCommandTally(
        runCount: 1, totalDuration: run.duration, slowestDuration: run.duration,
        slowestDirectory: run.directory, measuredRunCount: peak == nil ? 0 : 1,
        totalPeakMemory: peak ?? 0, highestPeakMemory: peak ?? 0))
  }

  mutating func merge(_ other: GitCommandTally) {
    runCount += other.runCount
    totalDuration += other.totalDuration
    if other.slowestDuration > slowestDuration || slowestDirectory == nil {
      slowestDuration = other.slowestDuration
      slowestDirectory = other.slowestDirectory
    }
    measuredRunCount += other.measuredRunCount
    totalPeakMemory += other.totalPeakMemory
    highestPeakMemory = max(highestPeakMemory, other.highestPeakMemory)
  }

  static func byCommand(_ runs: [GitRun]) -> [String: GitCommandTally] {
    runs.reduce(into: [:]) { tallies, run in tallies[run.command, default: .init()].add(run) }
  }
}
