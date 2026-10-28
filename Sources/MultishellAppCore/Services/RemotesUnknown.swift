/// Create Pull Request where git could not list the remotes to push the branch to.
struct RemotesUnknown: Error {
  let branch: String
}
