import Foundation
import MultishellCore
import MultishellServices

/// What the PR page's Send writes: checked failing checks with their logs' tails,
/// then checked threads; see Docs/design/services/send-feedback.md.
enum PullRequestHandoff {
  /// A comment's diff ends at its line; the lines just above it place it.
  private static var hunkLineCount: Int { 8 }

  static func introduction(number: Int) -> String {
    t("handoff.pull-request-introduction", number)
  }

  static func fileName(number: Int, worktreeNamed name: String) -> String {
    AgentHandoff.fileName("pr-\(number)", forWorktreeNamed: name)
  }

  /// `logs` by item, a failed read's words in place of one; a `localTip` other
  /// than the head the checks ran on is said, without guessing which is ahead.
  static func entries(
    of items: [PullRequestHandoffItem],
    logs: [HandoffItemID: CheckLogRead],
    localTip: String?,
  ) -> [AgentHandoffEntry] {
    items.map { item in
      switch item {
      case .check(let check, let head):
        entry(
          of: check,
          head: head,
          log: logs[item.candidate.id] ?? .noLog,
          localTip: localTip,
        )

      case .thread(let thread):
        entry(of: thread)
      }
    }
  }

  private static func entry(
    of check: PullRequestCheck,
    head: String,
    log: CheckLogRead,
    localTip: String?,
  ) -> AgentHandoffEntry {
    let ranElsewhere = localTip.map { !$0.namesSameCommit(as: head) } ?? false
    var caveats: [String] = []
    if ranElsewhere { caveats.append(t("handoff.ran-on-other-commit", head.abbreviatedCommit)) }
    var quote: [String] = []
    switch log {
    case .read(let log):
      let tail = HandoffLogTail.lines(of: log.text)
      quote = tail.lines
      let cutCount = log.earlierLineCount + tail.cutCount
      if cutCount > 0 { caveats.append(t("handoff.earlier-lines-cut", cutCount)) }
      if tail.lines.isEmpty { caveats.append(t("handoff.log-empty")) }

    case .noLog:
      break

    case .failed(let reason):
      caveats.append(t("handoff.log-not-read", reason))
    }
    let text =
      check.link.map { t("handoff.check-text", $0.absoluteString) }
      ?? t("handoff.check-text-no-link")
    return AgentHandoffEntry(
      heading: check.displayName,
      caveat: caveats.isEmpty ? nil : caveats.joined(separator: " "),
      quote: quote,
      text: text,
    )
  }

  private static func entry(of thread: PullRequestThread) -> AgentHandoffEntry {
    let comments = thread.comments.map { comment in
      t("handoff.thread-comment", comment.author ?? t("handoff.thread-ghost"), comment.body)
    }
    let link = thread.webPage.map { t("handoff.thread-link", $0.absoluteString) }
    return AgentHandoffEntry(
      heading: thread.placeLabel,
      caveat: thread.isOutdated ? t("handoff.thread-outdated") : nil,
      quote: hunkLines(of: thread),
      text: (comments + [link].compactMap(\.self)).joined(separator: "\n\n"),
    )
  }

  /// The end of the hunk the thread was written on; a comment on a whole file has none.
  private static func hunkLines(of thread: PullRequestThread) -> [String] {
    guard !thread.diffHunk.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
      return []
    }
    return Array(
      thread.diffHunk.split(omittingEmptySubsequences: false, whereSeparator: \.isNewline)
        .map(String.init)
        .suffix(hunkLineCount)
    )
  }
}
