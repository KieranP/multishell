import MultishellAppCore
import MultishellCore
import SwiftUI

/// A file tab's bar: where the file is, its name, the counts of the diff the
/// tab drew, and the same menu a Files panel row has.
struct FileTabBar: View {
  private static let height: Double = 30

  let model: AppModel
  let tab: FileTab
  let reading: FileTabReading?
  let theme: Theme

  private var rows: FileTabRows? {
    if case .text(let rows) = reading?.content { rows } else { nil }
  }

  /// What the counts and the arrows both show for.
  private var changedLineCounts: FileLineCounts? {
    rows.flatMap { $0.hasLineChanges ? $0.lineCounts : nil }
  }

  var body: some View {
    HStack(spacing: 6) {
      if let folder = tab.folderCrumb {
        Text(folder)
          .foregroundStyle(theme.fileTab.textTertiary)
          .lineLimit(1)
          .truncationMode(.head)
      }
      Text(tab.fileName)
        .fontWeight(.semibold)
        .strikethrough(reading?.isFileGone == true)
        .foregroundStyle(theme.fileTab.text)
        .lineLimit(1)
        .layoutPriority(1)
      if let changedLineCounts {
        FileLineCountsText(
          counts: changedLineCounts,
          theme: theme,
          size: model.metrics.caption,
          showsZeroSides: false,
        )
      }
      if rows?.hasModeChange == true {
        Text(t("file.mode-changed")).foregroundStyle(theme.fileTab.textTertiary)
      }
      Spacer(minLength: 8)
      if changedLineCounts != nil {
        ChangeStepButtons(model: model, tabID: tab.id, palette: theme.fileTab)
      }
      if model.offersLayoutSwitch(for: tab) { layoutSwitch }
      actionsMenu
    }
    .font(model.metrics.font(size: model.metrics.secondary))
    .padding(.leading, 12)
    .padding(.trailing, 8)
    .frame(height: Self.height)
    .background(theme.fileTab.background)
    .hairline(.bottom, theme.fileTab)
  }

  /// Unified, the changes inline; Split, the last commit beside the file.
  private var layoutSwitch: some View {
    SegmentedSwitch(
      label: t("file.layout"),
      options: [(t("file.unified"), .unified), (t("file.split"), .split)],
      selection: Binding(get: { model.layout(of: tab) }, set: { model.setFileTabLayout($0) }),
      palette: theme.fileTab,
      metrics: model.metrics,
    )
  }

  private var actionsMenu: some View {
    HeaderActionsMenu(help: t("file.actions"), palette: theme.fileTab) {
      FileActions(model: model, worktreeID: tab.worktreeID, path: tab.path)
    }
  }
}
