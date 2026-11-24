import Foundation

@testable import MultishellServices

extension PullRequestThread {
  static func sample(
    id: String = "t1",
    path: String = "Sources/App.swift",
    line: Int? = 12,
    originalLine: Int? = 10,
    isOutdated: Bool = false,
    comments: [String] = ["Guard it."],
    hunk: String = "@@ -1,2 +1,2 @@\n-let a\n+let b",
  ) -> Self {
    PullRequestThread(
      id: id,
      path: path,
      line: line,
      originalLine: originalLine,
      isOutdated: isOutdated,
      diffHunk: hunk,
      comments: comments.enumerated().map { index, body in
        PullRequestThreadComment(
          id: "\(id)-c\(index)",
          author: "jt",
          body: body,
          bodyText: body,
          url: URL(string: "https://github.com/me/demo/pull/44#discussion_r\(index)"),
        )
      },
    )
  }
}
