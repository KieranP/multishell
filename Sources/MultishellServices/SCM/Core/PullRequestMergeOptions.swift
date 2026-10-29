/// How a pull request may be merged, read as the merge form opens.
public struct PullRequestMergeOptions: Hashable, Sendable {
  /// The methods the repository allows, never none, in `offered` order.
  public let methods: [PullRequestMergeMethod]
  /// The one the host's own merge box opens on, among `methods`.
  public let defaultMethod: PullRequestMergeMethod
  /// The host's own message for each method that takes one.
  public let messages: [PullRequestMergeMethod: PullRequestMergeMessage]
  /// The repository lets a pull request merge itself once its checks pass.
  public let allowsAutoMerge: Bool
  /// The user may write to the base repository, which merging needs.
  public let viewerMayMerge: Bool
}
