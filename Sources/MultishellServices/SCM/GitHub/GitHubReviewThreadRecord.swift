import Foundation
import MultishellCore

/// One page of `query`'s answer: a pull request's review threads, resolved or
/// not, and where the next page starts.
struct GitHubReviewThreadRecord: Decodable {
  /// The answer's `data`; `gh` exits non-zero for any `errors` beside it.
  struct Envelope: Decodable {
    struct Answer: Decodable {
      let repository: Repository?
    }

    let data: Answer?
  }

  struct Repository: Decodable {
    let pullRequest: PullRequestRecord?
  }

  struct PullRequestRecord: Decodable {
    let reviewThreads: Connection
  }

  struct Connection: Decodable {
    let pageInfo: PageInfo
    let nodes: [GitHubReviewThreadRecord]
  }

  struct PageInfo: Decodable {
    let hasNextPage: Bool
    let endCursor: String?
  }

  struct Comments: Decodable {
    let nodes: [Comment]
  }

  struct Hunks: Decodable {
    struct Hunk: Decodable {
      let diffHunk: String
    }

    let nodes: [Hunk]
  }

  struct Comment: Decodable {
    struct Author: Decodable {
      let login: String
    }

    let id: String
    let author: Author?
    let body: String
    let url: URL?
  }

  /// A hundred threads a page, the most GitHub gives, and a thread's first
  /// hundred comments; the hunk only of the first, which places the thread.
  static let query = """
    query($owner: String!, $name: String!, $number: Int!, $after: String) {
      repository(owner: $owner, name: $name) {
        pullRequest(number: $number) {
          reviewThreads(first: 100, after: $after) {
            pageInfo { hasNextPage endCursor }
            nodes {
              id isResolved isOutdated path line originalLine
              firstComment: comments(first: 1) { nodes { diffHunk } }
              comments(first: 100) { nodes { id author { login } body url } }
            }
          }
        }
      }
    }
    """

  let id: String
  let isResolved: Bool
  let isOutdated: Bool
  let path: String
  let line: Int?
  let originalLine: Int?
  let firstComment: Hunks
  let comments: Comments

  /// The unresolved threads of one page, and the cursor of the next where there is one.
  static func page(from json: Data) throws -> (threads: [PullRequestThread], next: String?) {
    let envelope = try ToolAnswer.decode(Envelope.self, from: json)
    guard let connection = envelope.data?.repository?.pullRequest?.reviewThreads else {
      throw ServiceReadFailure.failed(t("integration.unreadable-answer"))
    }
    let threads = connection.nodes.filter { !$0.isResolved && !$0.comments.nodes.isEmpty }
      .map { record in
        PullRequestThread(
          id: record.id,
          path: record.path,
          line: record.line,
          originalLine: record.originalLine,
          isOutdated: record.isOutdated,
          diffHunk: record.firstComment.nodes.first?.diffHunk ?? "",
          comments: record.comments.nodes.map { comment in
            PullRequestThreadComment(
              id: comment.id,
              author: comment.author?.login,
              body: comment.body,
              url: comment.url,
            )
          },
        )
      }
    return (threads, connection.pageInfo.hasNextPage ? connection.pageInfo.endCursor : nil)
  }
}
