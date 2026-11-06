import MultishellAppCore
import SwiftUI

extension SidebarRows {
  /// Every row the sidebar lists, at the width that truncates none of them.
  static func idealWidth(of model: AppModel) -> Double {
    let rows = VStack(spacing: UIMetrics.sidebarRowSpacing) {
      SidebarRows(
        model: model,
        entries: model.sidebarEntries,
        sessions: model.sessionIDsByWorktree,
        projectInsertion: .constant(nil),
        tabDropTarget: .constant(nil),
        endProjectDrag: {},
      )
    }
    return ListIdealWidth.of(rows.padding(.horizontal, UIMetrics.sidebarListSideInset))
  }
}
