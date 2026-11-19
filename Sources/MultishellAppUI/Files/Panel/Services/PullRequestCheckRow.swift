import MultishellAppCore
import MultishellCore
import MultishellServices
import SwiftUI

/// One check under the merge path's Checks step; one with a page of its own
/// opens it at a click. A failing one carries its checkbox or sent bubble.
struct PullRequestCheckRow: View {
  let model: AppModel
  let check: PullRequestCheck
  let worktreeID: Worktree.ID
  /// Every row keeps the trailing slot while any check can be sent, so the
  /// Required tags stay in one column.
  let showsHandoffSlot: Bool
  let candidate: HandoffCandidate?
  let theme: Theme

  var body: some View {
    HStack(spacing: 8) {
      if check.webPage != nil {
        Button {
          model.openCheck(check)
        } label: {
          row.contentShape(.rect)
        }
        .buttonStyle(.plain)
      } else {
        row
      }
      if showsHandoffSlot {
        HandoffItemControl(
          model: model,
          candidate: candidate,
          worktreeID: worktreeID,
          itemName: check.displayName,
          theme: theme,
        )
      }
    }
  }

  private var row: some View {
    let metrics = model.metrics
    return HStack(spacing: 8) {
      CIRunGlyph(
        status: check.status,
        theme: theme,
        palette: theme.filesPanel,
        size: metrics.servicePageRowGlyphSize,
      )
      Text(check.displayName)
        .font(metrics.font(size: metrics.secondary))
        .foregroundStyle(theme.filesPanel.text)
        .lineLimit(1)
        .truncationMode(.middle)
      Spacer(minLength: 4)
      if check.isRequired {
        Text(t("panel.required").uppercased())
          .font(metrics.font(size: metrics.servicePageMarkSize, weight: .semibold))
          .foregroundStyle(theme.filesPanel.text)
      }
    }
    .frame(height: metrics.paneRowHeight)
    .help(check.displayName)
    .accessibilityElement(children: .combine)
    .accessibilityValue(AccessibilityText.ciStatus(check.status))
  }
}
