import MultishellAppCore
import MultishellCore
import SwiftUI

/// What one of the All changes tab's gaps holds: a fold or a notice, the same
/// in Unified and Split.
struct AllChangesGapItemView: View {
  let model: AppModel
  let tab: AllChangesTab
  let path: String
  let item: AllChangesGapItem
  let codeX: CGFloat
  let theme: Theme

  var body: some View {
    switch item.kind {
    case .fold(let lines):
      AllChangesFoldRow(
        model: model,
        tabID: tab.id,
        path: path,
        lines: lines,
        codeX: codeX,
        theme: theme,
      )

    case .notice(let notice):
      AllChangesFileNotice(
        model: model,
        worktreeID: tab.worktreeID,
        path: path,
        notice: notice,
        theme: theme,
      )
    }
  }
}
