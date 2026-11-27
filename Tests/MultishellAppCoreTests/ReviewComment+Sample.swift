@testable import MultishellCore

extension ReviewComment {
  /// An on-disk comment in the Modified scope; `Sources/App.swift` unless `path` says otherwise.
  static func sample(
    path: String = "Sources/App.swift",
    lines: ClosedRange<Int> = 3...4,
    quote: [String] = ["let a = 1", "let b = 2"],
    text: String = "Guard it.",
  ) -> Self {
    ReviewComment(
      path: path,
      side: .onDisk,
      scope: .modified,
      lines: lines,
      quote: quote,
      text: text,
    )
  }
}
