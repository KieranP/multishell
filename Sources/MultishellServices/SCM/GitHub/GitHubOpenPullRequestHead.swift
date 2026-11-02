import Foundation
import MultishellCore

/// One element of `gh pr list --state open --json number,headRefName`. Merge
/// state is left out: GitHub fails a page of open pull requests that asks it.
struct GitHubOpenPullRequestHead: Decodable {
  static let fields = ["number", "headRefName"]

  let number: Int?
  let headRefName: String?

  /// Each head that names both; output that is not a JSON array fails the read.
  static func heads(from json: Data) throws -> [(number: Int, branch: String)] {
    try ToolAnswer.decode(LossyArray<Self>.self, from: json).elements.compactMap { head in
      guard let number = head.number, let branch = head.headRefName else { return nil }
      return (number, branch)
    }
  }
}
