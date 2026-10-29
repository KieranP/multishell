import Foundation
import MultishellCore
import MultishellServices

/// What the row's tooltip and a screen reader say of the services.
extension WorktreeServices {
  /// "CircleCI passed", and the commit it ran where that is not the local tip;
  /// the CI glyph's spoken label too.
  public var ciRunText: String? {
    guard let ciRun, let ciIntegration else { return nil }
    let status = ciRun.statusText(provider: ciIntegration.displayName)
    guard localTip != nil, !ciRun.ran(localTip) else { return status }
    return t("ci.other-commit", status, ciRun.shortCommit)
  }

  /// A merged pull request the branch has gone past.
  public var outgrownText: String? {
    outgrownPullRequest.map { t("pull-request.outgrown", String($0.number)) }
  }

  /// Why what is shown may be old, and since when.
  var readProblemText: String? {
    guard let readProblem else { return nil }
    let reason = readProblem.failure.reason(integration: readProblem.integration)
    guard let answered = readProblem.lastAnsweredAt else {
      return t("services.never-read", reason)
    }
    // An answer from another day says the day, or it reads as hours old.
    let date: Date.FormatStyle.DateStyle =
      Calendar.current.isDateInToday(answered) ? .omitted : .abbreviated
    return t("services.stale", answered.formatted(date: date, time: .shortened), reason)
  }

  /// The pull request list's own failure, for its page, which offers Merge from
  /// it; a CI read's failure is the CI page's to say.
  public var pullRequestReadProblemText: String? {
    readProblem?.source == .pullRequests ? readProblemText : nil
  }

  /// The row's tooltip: the pull request's number and title, its state, the
  /// run, and anything that makes the rest out of date.
  public var tooltip: String {
    var lines: [String] = []
    if let pullRequest {
      lines += [pullRequest.numberedTitle, pullRequest.stateText]
    }
    lines += [outgrownText, ciRunText, readProblemText].compactMap(\.self)
    return lines.joined(separator: "\n")
  }

  /// The pull request glyph's spoken label: its number and state, or that the
  /// branch outgrew the merged one the glyph then draws.
  public var spokenPullRequest: String? {
    pullRequest.map { t("spoken.pull-request", String($0.number), $0.stateText) }
      ?? outgrownText
  }

  /// What a screen reader says of the row's glyphs, and what the tooltip says
  /// makes them old, as it has no tooltip to hover; nothing where none is drawn.
  var spokenSummary: String? {
    guard showsAnything else { return nil }
    let parts = [spokenPullRequest, ciRunText, readProblemText].compactMap(\.self)
    return parts.isEmpty ? nil : parts.joined(separator: ", ")
  }
}
