import MultishellAppCore
import MultishellCore
import SwiftUI

/// Unified, the changes inline; Split, the committed side beside the file. One
/// choice for every file tab and the All changes tab.
struct FileTabLayoutSwitch: View {
  /// The switch's choices, which a file tab's view menu lists too.
  static var options: [(title: String, value: FileTabLayout)] {
    [(t("file.unified"), .unified), (t("file.split"), .split)]
  }

  let model: AppModel
  let selection: Binding<FileTabLayout>
  let palette: AreaPalette

  var body: some View {
    SegmentedSwitch(
      label: t("file.layout"),
      options: Self.options,
      selection: selection,
      palette: palette,
      metrics: model.metrics,
    )
  }

  static func selection(in model: AppModel, for tab: FileTab) -> Binding<FileTabLayout> {
    Binding(get: { model.layout(of: tab) }, set: { model.setFileTabLayout($0) })
  }

  /// The All changes tab's, the choice every file tab follows: a file only added
  /// or removed shows on its one side, padded opposite.
  static func allChangesSelection(in model: AppModel) -> Binding<FileTabLayout> {
    Binding(get: { model.workspace.fileTabLayout }, set: { model.setFileTabLayout($0) })
  }
}
