import MultishellAppCore
import MultishellCore
import SwiftUI

/// The sidebar's list: the Agents row, the Projects header and each project's
/// block, lazy in the sidebar and laid out whole for its edge's fit.
struct SidebarRows: View {
  let model: AppModel
  let entries: [SidebarListing.Entry]
  let sessions: SessionIDsByWorktree
  @Binding var projectInsertion: ProjectInsertion?
  @Binding var tabDropTarget: Worktree.ID?
  let endProjectDrag: () -> Void

  var body: some View {
    let theme = model.currentTheme
    let metrics = model.metrics
    SidebarAgentsRow(
      counts: model.sidebarLaneCounts,
      isSelected: model.showsAgentBoard,
      theme: theme,
      metrics: metrics,
      select: { model.showAgentBoard() },
    )
    .equatable()
    .padding(.bottom, 4)

    ProjectsSectionHeader(model: model, theme: theme, metrics: metrics)

    ForEach(entries, id: \.project.id) { entry in
      let ordered = model.orderedWorktrees(of: entry, sessions: sessions)
      ProjectBlock(
        model: model,
        project: entry.project,
        worktrees: ordered.worktrees,
        hiddenWorktrees: ordered.hiddenWorktrees,
        isExpanded: entry.isExpanded,
        isHiddenSectionExpanded: entry.isHiddenSectionExpanded,
        showsHiddenSectionRow: entry.showsHiddenSectionRow,
        showsHiddenWorktrees: entry.showsHiddenWorktrees,
        sessions: sessions,
        theme: theme,
        projectInsertion: $projectInsertion,
        tabDropTarget: $tabDropTarget,
        endProjectDrag: endProjectDrag,
      )
    }
  }
}
