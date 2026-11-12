import Foundation
import MultishellCore

extension Helper {
  static func runReview(
    _ arguments: ArraySlice<String>,
    environment: [String: String],
  ) throws
    -> Int32
  {
    let topic = ControlCommand.review.rawValue
    let (words, optionWords) = positionals(arguments.dropFirst())
    switch (arguments.first, words.count) {
    case ("list", 0):
      let options = try CommandOptions(optionWords, valued: ["worktree"], topic: topic)
      let worktree = try reviewedWorktree(in: options, topic: topic)
      return try ask(.listReviewComments(worktree: worktree), environment: environment)

    case ("add", 3):
      let options = try CommandOptions(
        optionWords,
        valued: ["worktree"],
        flags: ["removed"],
        topic: topic,
      )
      let order = ReviewCommentOrder(
        worktreeID: try reviewedWorktree(in: options, topic: topic),
        path: words[0],
        side: options.has("removed") ? .committed : .onDisk,
        lines: try reviewLines(words[1], topic: topic),
        text: words[2],
      )
      let request = ControlRequest.addReviewComment(order)
      // A tab just opened may still be reading its rows, as for `tabs step`.
      return try askOnceRead(request, of: nil, environment: environment)

    case ("send", 0):
      let options = try CommandOptions(optionWords, valued: ["worktree", "to"], topic: topic)
      let request = ControlRequest.sendReview(
        worktree: try reviewedWorktree(in: options, topic: topic),
        to: try options["to"].map { try tabOrPaneID($0, topic: topic) },
      )
      return try ask(request, environment: environment)

    case ("clear", 0):
      let options = try CommandOptions(
        optionWords,
        valued: ["worktree"],
        flags: ["sent"],
        topic: topic,
      )
      let request = ControlRequest.clearReviewComments(
        worktree: try reviewedWorktree(in: options, topic: topic),
        sentOnly: options.has("sent"),
      )
      return try ask(request, environment: environment)

    default:
      throw UsageError(
        "review needs: list, add PATH LINES TEXT, send or clear",
        topic: topic,
      )
    }
  }

  private static func reviewedWorktree(in options: CommandOptions, topic: String) throws -> String?
  {
    try options["worktree"].map { try worktreeID($0, topic: topic) }
  }

  /// `806` or `806-810`, numbers from 1 with the first no later than the last.
  private static func reviewLines(_ text: String, topic: String) throws -> ClosedRange<Int> {
    let parts = text.split(separator: "-", omittingEmptySubsequences: false).map { Int($0) }
    guard (1...2).contains(parts.count), let first = parts.first ?? nil,
      let last = parts.last ?? nil, first >= 1, first <= last
    else {
      throw UsageError("not lines: \(text); give one number or FIRST-LAST", topic: topic)
    }
    return first...last
  }
}
