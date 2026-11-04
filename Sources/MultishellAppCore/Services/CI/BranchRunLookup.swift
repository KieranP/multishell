import Foundation
import MultishellServices

/// A branch the project's recent runs left out, asked about alone, and the
/// upstream tip it was asked at.
struct BranchRunLookup: Equatable {
  /// How long after a push the tip's run is waited for. A tip CircleCI never
  /// runs, a `[skip ci]` commit say, then stands on the run before it.
  private static let tipRunWait: TimeInterval = 600

  let upstreamTip: String?
  /// `nil` where the branch has never run.
  let run: CIRun?
  /// When this tip was first asked about, kept through the asks after it.
  let tipAskedSince: Date

  /// Asked again once the branch is pushed to, until its run ends, on hold
  /// included, and until the tip's own run appears; see services.md.
  func stillAnswers(upstreamTip tip: String?, now: Date) -> Bool {
    guard tip == upstreamTip, run?.isFinished != false, run?.status != .unknown else {
      return false
    }
    return run?.ran(tip) == true || now.timeIntervalSince(tipAskedSince) >= Self.tipRunWait
  }
}
