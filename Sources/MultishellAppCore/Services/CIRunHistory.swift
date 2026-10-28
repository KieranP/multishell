import MultishellServices

/// A branch's newest runs, newest first, read while the panel shows them.
/// Runtime only; see Docs/design/services.md.
struct CIRunHistory: Equatable, Sendable {
  /// The branch's name on the remote.
  let branch: String
  /// The last runs read, kept through a failed read after them.
  var runs: [CIRun]
  var failure: ServiceReadFailure?
  /// The row's newest run when last asked, answered or not: a new one reads
  /// the history again.
  var askedForRun: CIRun.ID?
}
