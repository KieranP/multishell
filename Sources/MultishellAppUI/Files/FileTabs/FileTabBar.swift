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

  var body: some View {
    HStack(spacing: 6) {
      if let folder = tab.folderCrumb {
        Text(folder)
          .foregroundStyle(theme.textTertiary)
          .lineLimit(1)
          .truncationMode(.head)
      }
      Text(tab.fileName)
        .fontWeight(.semibold)
        .strikethrough(reading?.isFileGone == true)
        .foregroundStyle(theme.textPrimary)
        .lineLimit(1)
        .layoutPriority(1)
      if let rows, rows.hasLineChanges {
        FileLineCountsText(
          counts: rows.lineCounts,
          theme: theme,
          size: model.metrics.caption,
          showsZeroSides: false,
        )
      }
      if rows?.hasModeChange == true {
        Text(t("file.mode-changed")).foregroundStyle(theme.textTertiary)
      }
      Spacer(minLength: 8)
      if model.offersLayoutSwitch(for: tab) { layoutSwitch }
      actionsMenu
    }
    .font(model.metrics.font(size: model.metrics.secondary))
    .padding(.leading, 12)
    .padding(.trailing, 8)
    .frame(height: Self.height)
    .background(theme.backgroundColor)
    .hairline(.bottom, theme)
  }

  /// Unified, the changes inline; Split, the last commit beside the file.
  private var layoutSwitch: some View {
    Picker(
      t("file.layout"),
      selection: Binding(get: { model.layout(of: tab) }, set: { model.setFileTabLayout($0) }),
    ) {
      Text(t("file.unified")).tag(FileTabLayout.unified)
      Text(t("file.split")).tag(FileTabLayout.split)
    }
    .compactSegmented()
  }

  private var actionsMenu: some View {
    HeaderActionsMenu(help: t("file.actions"), theme: theme) {
      FileActions(model: model, worktreeID: tab.worktreeID, path: tab.path)
    }
  }
}
