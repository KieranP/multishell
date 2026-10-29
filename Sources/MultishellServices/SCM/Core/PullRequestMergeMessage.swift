/// The commit message a merge or squash lands with.
public struct PullRequestMergeMessage: Hashable, Sendable {
  public var subject: String
  public var body: String

  public init(subject: String, body: String) {
    self.subject = subject
    self.body = body
  }
}
