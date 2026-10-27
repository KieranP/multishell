/// Create Pull Request on a repository with no remote to push the branch to.
struct NoRemoteToPublishTo: Error {
  let branch: String
}
