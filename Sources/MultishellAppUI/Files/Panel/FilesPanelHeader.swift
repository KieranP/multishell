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
        .foregroundStyle(theme.textSecondary)
      Spacer(minLength: 8)
      Picker(
        t("files-panel.which"),
        selection: Binding(
          get: { model.filesPanelState(of: worktreeID).mode },
          set: { model.setFilesPanelMode($0) },
        ),
      ) {
        Text(t("files-panel.all")).tag(FilesPanelMode.all)
        Text(t("files-panel.modified")).tag(FilesPanelMode.modified)
      }
      .compactSegmented()
    }
    .padding(.leading, 12)
    .padding(.trailing, 8)
    .frame(height: model.metrics.tabHeight)
    .background(theme.chromeColor)
    .hairline(.bottom, theme)
  }
}
