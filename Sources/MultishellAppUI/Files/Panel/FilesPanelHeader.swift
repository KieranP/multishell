import MultishellAppCore
import MultishellCore
import SwiftUI

/// The panel's name and its All / Modified switch, on the tab strip's band.
struct FilesPanelHeader: View {
  let model: AppModel
  let worktreeID: Worktree.ID
  let theme: Theme

  var body: some View {
    let metrics = model.metrics
    HStack(spacing: 6) {
      Text(t("files-panel.title"))
        .font(metrics.font(size: metrics.secondary, weight: .semibold))
        .foregroundStyle(theme.header.textSecondary)
      Spacer(minLength: 8)
      SegmentedSwitch(
        label: t("files-panel.which"),
        options: [(t("files-panel.all"), .all), (t("files-panel.modified"), .modified)],
        selection: Binding(
          get: { model.filesPanelState(of: worktreeID).mode },
          set: { model.setFilesPanelMode($0) },
        ),
        theme: theme,
        section: .header,
        metrics: metrics,
      )
    }
    .padding(.leading, 12)
    .padding(.trailing, 8)
    .frame(height: model.metrics.tabHeight)
    .background(theme.header.background)
    .hairline(.bottom, theme.header)
  }
}
