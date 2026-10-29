/// What the host's tool refused of a merge, an auto-merge or its cancelling.
struct PullRequestMergeFailure: Error {
  let number: Int
  let action: MergeAction
  let underlying: any Error
}
