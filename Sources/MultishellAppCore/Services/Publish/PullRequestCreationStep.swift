/// What Create Pull Request does once git has said what the remote lacks.
enum PullRequestCreationStep {
  /// The remote lacks the branch or commits: push, once the user says so.
  case ask(PendingBranchPublish)
  /// git could not list the remotes or count what one lacks, or there is none.
  case fail(any Error)
  /// The remote has every commit: the host's page opens against this head.
  case open(head: String, remote: String)
}
