import MultishellAppCore
import MultishellCore
import SwiftUI

/// Modified or Branch: one switch drawn in the panel's Git list and in each
/// file tab's bar, both setting the one choice they follow.
struct ChangeScopeSwitch: View {
  let model: AppModel
  let palette: AreaPalette
  var fillsWidth = false

  var body: some View {
    SegmentedSwitch(
      label: t("files-panel.change-scope"),
      options: [(t("files-panel.modified"), .modified), (t("files-panel.branch"), .branch)],
      selection: Binding(
        get: { model.workspace.changeScope },
        set: { model.setChangeScope($0) },
      ),
      palette: palette,
      metrics: model.metrics,
      fillsWidth: fillsWidth,
    )
    .help(t("files-panel.change-scope-help"))
  }
}
