import MultishellAppCore
import MultishellCore
import MultishellServices
import SwiftUI

/// A pull request's title, number, branch and state, with the corner glyph
/// that opens it on the host: the panel's card and the row's popover alike.
struct PullRequestSummary: View {
  let model: AppModel
  let worktree: Worktree
  let pullRequest: PullRequest
  let theme: Theme

  /// The title, then its number faint, wrapping as one line of text.
  private var title: AttributedString {
    var number = AttributedString(" " + t("pull-request.number", String(pullRequest.number)))
    number.foregroundColor = theme.header.textTertiary
    return AttributedString(pullRequest.title) + number
  }

  var body: some View {
    let metrics = model.metrics
    VStack(alignment: .leading, spacing: 6) {
      HStack(alignment: .firstTextBaseline, spacing: UIMetrics.serviceCardGlyphSpacing) {
        PullRequestGlyph(
          mark: PullRequestMark(pullRequest),
          theme: theme,
          palette: theme.header,
          size: metrics.serviceGlyphSize,
        )
        Text(title)
          .font(metrics.font(size: metrics.secondary, weight: .semibold))
          .foregroundStyle(theme.header.text)
          .fixedSize(horizontal: false, vertical: true)
      }
      .padding(.trailing, ExternalLinkButton.clearance(forSize: metrics.glyph))
      // Under the title, and running on under the corner link.
      Group {
        Text(t("panel.branch-into-base", pullRequest.headBranch, pullRequest.baseBranch))
          .font(.system(size: metrics.caption, design: .monospaced))
          .foregroundStyle(theme.header.textSecondary)
          .lineLimit(1)
          .truncationMode(.middle)
        Text(pullRequest.stateText)
          .font(metrics.font(size: metrics.caption))
          .foregroundStyle(theme.header.textSecondary)
          .fixedSize(horizontal: false, vertical: true)
      }
      .padding(.leading, metrics.serviceCardTextIndent)
    }
    .cornerLink(
      help: t("action.open-on", model.pullRequestHostName(of: worktree) ?? ""),
      size: metrics.glyph,
      color: theme.header.textSecondary,
    ) {
      Task { await model.openPullRequest(of: worktree) }
    }
  }
}
