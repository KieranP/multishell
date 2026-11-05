import MultishellAppCore
import MultishellCore
import SwiftUI

/// Modified or Branch: one switch drawn in the panel's Changes list and in each
/// file tab's bar, both setting the one choice they follow.
struct ChangeScopeSwitch: View {
  /// The switch's choices, which a file tab's view menu lists too.
  static var options: [(title: String, value: ChangeScope)] {
    [(t("files-panel.modified"), .modified), (t("files-panel.branch"), .branch)]
  }

  let model: AppModel
  let palette: AreaPalette
  var fillsWidth = false

  var body: some View {
    SegmentedSwitch(
      label: t("files-panel.change-scope"),
      options: Self.options,
      selection: Self.selection(in: model),
      palette: palette,
      metrics: model.metrics,
      fillsWidth: fillsWidth,
    )
    .help(t("files-panel.change-scope-help"))
  }

  static func selection(in model: AppModel) -> Binding<ChangeScope> {
    Binding(get: { model.workspace.changeScope }, set: { model.setChangeScope($0) })
  }
}
