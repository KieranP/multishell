import Foundation
import MultishellCore
import MultishellServices

/// What the CI page's Send writes for the agent: the checked failures of the
/// newest run as one note; see Docs/design/services/send-feedback.md.
enum CIHandoff {
  static func introduction(provider: String) -> String {
    t("handoff.ci-introduction", provider)
  }

  /// A `localTip` other than the run's commit is said, without guessing which is ahead.
  static func entries(
    of items: [CIHandoffItem],
    run: CIRun,
    provider: String,
    localTip: String?,
  ) -> [AgentHandoffEntry] {
    let ranElsewhere = localTip.map { !run.ran($0) } ?? false
    return items.map { item in
      let tail = item.excerpt.map(HandoffLogTail.lines(of:))
      let caveats = [
        ranElsewhere ? t("handoff.ran-on-other-commit", run.shortCommit) : nil,
        tail == nil ? reportMissing(of: item) : nil,
        (tail?.cutCount ?? 0) > 0 ? t("handoff.earlier-lines-cut", tail?.cutCount ?? 0) : nil,
      ]
      .compactMap(\.self)
      return AgentHandoffEntry(
        heading: item.heading,
        caveat: caveats.isEmpty ? nil : caveats.joined(separator: " "),
        quote: tail?.lines ?? [],
        text: text(of: item, provider: provider),
      )
    }
  }

  static func fileName(forWorktreeNamed name: String) -> String {
    AgentHandoff.fileName("ci", forWorktreeNamed: name)
  }

  /// A run still going reads its report once it ends; an ended one's was read,
  /// naming no job here, or never was.
  private static func reportMissing(of item: CIHandoffItem) -> String {
    if item.awaitsReport { return t("handoff.ci-report-unread") }
    return item.isReportRead ? t("handoff.ci-report-silent") : t("handoff.ci-report-not-read")
  }

  private static func text(of item: CIHandoffItem, provider: String) -> String {
    guard let job = item.job else { return t("handoff.ci-run-output-text", provider) }
    return job.id.map { t("handoff.ci-job-text-with-id", provider, $0) }
      ?? t("handoff.ci-job-text", provider)
  }
}
