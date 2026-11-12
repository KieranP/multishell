import MultishellAppCore
import MultishellCore
import MultishellServices
import SwiftUI

/// One check under the merge path's Checks step; one with a page of its own
/// opens it at a click.
struct PullRequestCheckRow: View {
  let model: AppModel
  let check: PullRequestCheck
  let theme: Theme

  var body: some View {
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
