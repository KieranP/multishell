import Foundation
import MultishellCore
import MultishellServices

extension PullRequestThread {
  /// "Sources/App.swift:12", an outdated one by the line it was written on,
  /// one on the whole file by its path alone.
  public var placeLabel: String {
    (line ?? originalLine).map { "\(path):\($0)" } ?? path
  }

  /// Who started it, a deleted account by those words.
  public var authorName: String { comments.first?.author ?? t("handoff.thread-ghost") }
}
