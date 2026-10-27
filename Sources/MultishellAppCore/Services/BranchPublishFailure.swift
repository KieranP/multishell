/// A push Create Pull Request started that failed, with what git said.
struct BranchPublishFailure: Error {
  let branch: String
  let underlying: any Error
}
