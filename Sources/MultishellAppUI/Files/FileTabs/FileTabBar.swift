import MultishellAppCore
import MultishellCore
import SwiftUI

/// A file tab's bar: where the file is, its name, the counts of the diff the
/// tab drew, and the same menu a Files panel row has.
struct FileTabBar: View {
  private static let height: Double = 30
  private static let spacing: Double = 6

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
    let offersChangeScope = model.offersChangeScopeSwitch(for: tab)
    let offersLayout = model.offersLayoutSwitch(for: tab)
    // The switches on the bar where they fit beside the name, else in one
    // menu; whatever still overflows is cut, not drawn over the next group.
    ViewThatFits(in: .horizontal) {
      bar(switchesInMenu: false, offersChangeScope: offersChangeScope, offersLayout: offersLayout)
      bar(switchesInMenu: true, offersChangeScope: offersChangeScope, offersLayout: offersLayout)
    }
    .font(model.metrics.font(size: model.metrics.secondary))
    .padding(.leading, 12)
    .padding(.trailing, 8)
    .frame(height: Self.height)
    .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
    .clipped()
    .background(theme.fileTab.background)
    .hairline(.bottom, theme.fileTab)
  }

  /// The folder and the name as one, the folder carrying the gap to the name
  /// so a folder that gives way leaves the name where a root file's starts.
  private var location: some View {
    HStack(spacing: 0) {
      if let folder = tab.folderCrumb {
        ReadableTail(
          text: folder,
          leastWidth: UIMetrics.readableTailWidth(atSize: model.metrics.secondary),
          insets: EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: Self.spacing),
        )
        .foregroundStyle(theme.fileTab.textTertiary)
        // Measured as nothing, so a long folder gives way rather than moving the switches.
        .frame(idealWidth: 0, alignment: .leading)
      }
      Text(tab.fileName)
        .fontWeight(.semibold)
        .strikethrough(reading?.isFileGone == true)
        .foregroundStyle(theme.fileTab.text)
        .lineLimit(1)
        .layoutPriority(1)
    }
    .layoutPriority(1)
  }

  private var actionsMenu: some View {
    HeaderActionsMenu(help: t("file.actions"), palette: theme.fileTab) {
      FileActions(model: model, worktreeID: tab.worktreeID, path: tab.path)
    }
  }

  private func bar(
    switchesInMenu: Bool,
    offersChangeScope: Bool,
    offersLayout: Bool,
  ) -> some View {
    HStack(spacing: Self.spacing) {
      location
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
      if switchesInMenu {
        if offersChangeScope || offersLayout {
          FileTabViewMenu(
            model: model,
            tab: tab,
            offersChangeScope: offersChangeScope,
            offersLayout: offersLayout,
            palette: theme.fileTab,
          )
        }
      } else {
        if offersChangeScope { ChangeScopeSwitch(model: model, palette: theme.fileTab) }
        if offersLayout {
          FileTabLayoutSwitch(
            model: model,
            selection: FileTabLayoutSwitch.selection(in: model, for: tab),
            palette: theme.fileTab,
          )
        }
      }
      actionsMenu
    }
  }
}
