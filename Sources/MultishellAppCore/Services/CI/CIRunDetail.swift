import Foundation
import MultishellProcess
import MultishellServices

/// A run's workflows or failure report and the run as it stood then; when it
/// was read is kept apart, unobserved, so a same answer redraws nothing.
struct CIRunDetail<Value: Equatable & Sendable>: Equatable, Sendable {
  let value: Value
  let runStatus: CIRunStatus
  let runWasFinished: Bool

  /// Read once more when the run ends, and else at most at the pace a run under
  /// way is polled: two copies of a run read at different times can disagree.
  func stillDescribe(_ run: CIRun, readAt: Date?, now: Date = .now) -> Bool {
    if runWasFinished, runStatus == run.status { return true }
    if run.isFinished, !runWasFinished { return false }
    guard let readAt else { return false }
    return now.timeIntervalSince(readAt) < ServiceReadInterval.underWay.inSeconds
  }
}
