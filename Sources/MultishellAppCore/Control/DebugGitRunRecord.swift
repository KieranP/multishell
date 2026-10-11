import Foundation
import MultishellGitKit
import MultishellProcess

/// One git run as `multishell debug git` prints it: milliseconds and bytes.
struct DebugGitRunRecord: Encodable, Equatable {
  /// The sample it ended in, as `debug samples` numbers them.
  let sample: Int
  let command: String
  let directory: String
  let milliseconds: Double
  /// git's own lifetime peak, `nil` where it was not read.
  let peakMemory: UInt64?

  init(_ entry: DebugGitRunLog.Entry) {
    sample = entry.sample
    command = entry.run.command
    directory = entry.run.directory.path
    milliseconds = entry.run.duration.inMilliseconds
    peakMemory = entry.run.exitUsage?.peakFootprint
  }
}
