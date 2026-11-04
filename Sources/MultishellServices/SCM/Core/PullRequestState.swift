/// Where a pull request stands, a draft apart from open as the row draws it.
/// Raw values are what `worktrees show` prints.
public enum PullRequestState: String, Decodable, Hashable, Sendable {
  case closed
  case draft
  case merged
  case open
}
