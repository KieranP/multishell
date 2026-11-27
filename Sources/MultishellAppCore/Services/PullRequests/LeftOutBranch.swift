import MultishellServices

/// A branch the project's pull request list left out: its upstream tip, and
/// the repositories a pull request of its own is headed in.
struct LeftOutBranch {
  let tip: String?
  let repositories: [RemoteRepository]
}
