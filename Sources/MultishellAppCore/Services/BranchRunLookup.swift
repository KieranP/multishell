import MultishellServices

/// A branch the project's recent runs left out, asked about alone, and the
/// upstream tip it was asked at.
struct BranchRunLookup: Equatable {
  let upstreamTip: String?
  /// `nil` where the branch has never run.
  let run: CIRun?

  /// Asked again once the branch is pushed to, or until its run ends, on hold
  /// included, as an approval raises no event; see services.md.
  func stillAnswers(upstreamTip tip: String?) -> Bool {
    tip == upstreamTip && run?.isFinished != false
  }
}
