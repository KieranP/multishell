import MultishellAppCore
import MultishellCore
import SwiftUI

/// What one of the All changes tab's gaps holds: a file's header, a fold or a
/// notice, the same in Unified and Split.
struct AllChangesGapItemView: View {
  let model: AppModel
  let tab: AllChangesTab
  let document: AllChangesDocument
  let item: AllChangesGapItem
  let pendingComments: [String: Int]
  let theme: Theme

  var body: some View {
    let section = document.sections[item.section]
    switch item.kind {
    case .header:
      AllChangesFileHeader(
        model: model,
        tabID: tab.id,
        worktreeID: tab.worktreeID,
        section: section,
        pendingComments: pendingComments[section.path] ?? 0,
        showsFileGap: true,
        theme: theme,
      )

    case .fold(_, let lines):
      AllChangesFoldRow(
        model: model,
        tabID: tab.id,
        path: section.path,
        lines: lines,
        theme: theme,
      )

    case .notice(let notice):
      AllChangesFileNotice(
        model: model,
        worktreeID: tab.worktreeID,
        path: section.path,
        notice: notice,
        theme: theme,
      )

    // Its own view of the file, `AllChangesWholeFileLayer`'s, stands in the gap.
    case .wholeFile:
      EmptyView()
    }
  }
}
