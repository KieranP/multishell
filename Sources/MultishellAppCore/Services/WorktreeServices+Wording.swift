import Foundation
import MultishellCore
import MultishellServices

/// What the row's tooltip, the popover and a screen reader say of the services.
extension WorktreeServices {
  /// "CircleCI passed", and the commit it ran where that is not the local tip.
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
  public var readProblemText: String? {
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

  /// What a screen reader says of the row's glyphs, and what the tooltip says
  /// makes them old, as it has no tooltip to hover; nothing where none is drawn.
  public var spokenSummary: String? {
    guard showsAnything else { return nil }
    var parts: [String] = []
    if let pullRequest {
      parts.append(t("spoken.pull-request", String(pullRequest.number), pullRequest.stateText))
    }
    parts += [outgrownText, ciRunText, readProblemText].compactMap(\.self)
    return parts.isEmpty ? nil : parts.joined(separator: ", ")
  }
}
