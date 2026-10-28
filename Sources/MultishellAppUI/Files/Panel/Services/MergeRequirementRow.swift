import MultishellAppCore
import MultishellCore
import MultishellServices
import SwiftUI

/// One review, conflict or check row of the pull request page; a check with a
/// page of its own opens it at a click.
struct MergeRequirementRow: View {
  let model: AppModel
  let requirement: MergeReadiness.Requirement
  let base: String
  let theme: Theme

  var body: some View {
    if case .check(let check) = requirement.kind, check.webPage != nil {
      Button {
        model.openCheck(check)
      } label: {
        row.contentShape(.rect)
      }
      .buttonStyle(.plain)
    } else {
      row
    }
  }

  private var row: some View {
    let metrics = model.metrics
    let name = requirement.name(base: base)
    return HStack(spacing: 8) {
      if requirement.warnsOfConflicts {
        WarningShape()
          .stroke(
            theme.color(for: PullRequestMark.Corner.conflicts),
            style: StrokeStyle(
              lineWidth: UIMetrics.statusGlyphLineWidth(side: metrics.servicePageRowGlyphSize),
              lineCap: .round,
              lineJoin: .round,
            ),
          )
          .frame(width: metrics.servicePageRowGlyphSize, height: metrics.servicePageRowGlyphSize)
          .accessibilityHidden(true)
      } else {
        CIRunGlyph(
          status: requirement.status,
          theme: theme,
          palette: theme.filesPanel,
          size: metrics.servicePageRowGlyphSize,
        )
      }
      Text(name)
        .font(metrics.font(size: metrics.secondary))
        .foregroundStyle(
          requirement.status.drawsAttention ? theme.filesPanel.text : theme.filesPanel.textSecondary
        )
        .lineLimit(1)
        .truncationMode(.middle)
      Spacer(minLength: 4)
      if requirement.showsRequiredTag {
        Text(t("panel.required").uppercased())
          .font(metrics.font(size: metrics.servicePageMarkSize, weight: .semibold))
          .foregroundStyle(theme.filesPanel.textTertiary)
      }
    }
    .padding(.horizontal, UIMetrics.servicePageSideInset)
    .frame(height: metrics.paneRowHeight)
    .help(name)
    .accessibilityElement(children: .combine)
  }
}
