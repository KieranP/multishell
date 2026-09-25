import MultishellAppCore
import MultishellCore
import SwiftUI
import UniformTypeIdentifiers

/// The project tree, drawn by hand: macOS 26 renders a `NavigationSplitView`
/// sidebar as a floating glass panel, and a `List` brings that styling too.
struct SidebarView: View {
  let model: AppModel

  @State private var projectDropTarget: ProjectDropTarget?
  /// The worktree a dragged tab is hovering over, drawn on its row.
  @State private var tabDropTarget: Worktree.ID?

  /// Above the first row, so the gap holds whether or not the filter is shown.
  private static let listGap: CGFloat = 10

  var body: some View {
    let theme = model.currentTheme
    let metrics = model.metrics
    // Once per render, not per row: forty rows scanning every session four
    // times each was most of what a render cost.
    let sessions = model.worktreeSessions
    let shownProjects = filteredProjects
    VStack(spacing: 0) {
      SidebarHeader(
        showsFilterField: model.showsSidebarFilter,
        theme: theme,
        toggleFilter: { model.setShowsSidebarFilter(!model.showsSidebarFilter) },
        addProject: { Task { await model.chooseProject() } }
      )
      if model.showsSidebarFilter {
        SidebarFilterField(
          text: Bindable(model).sidebarFilterText, theme: theme, metrics: metrics,
          close: { model.setShowsSidebarFilter(false) })
      }
      ScrollView {
        LazyVStack(spacing: 1) {
          AgentBoardRow(
            counts: model.agentSidebarCounts,
            isSelected: model.showsAgentBoard,
            theme: theme,
            metrics: metrics,
            select: { model.showAgentBoard() }
          )
          .equatable()
          .padding(.bottom, 4)

          ProjectsHeader(model: model, theme: theme, metrics: metrics)

          ForEach(shownProjects, id: \.project.id) { entry in
            ProjectBlock(
              model: model,
              project: entry.project,
              worktrees: orderedWorktrees(of: entry, sessions: sessions),
              isForcedOpen: entry.isForcedOpen,
              sessions: sessions,
              theme: theme,
              projectDropTarget: $projectDropTarget,
              tabDropTarget: $tabDropTarget,
              endDrag: endDrag)
          }
        }
        .padding(.horizontal, 8)
        .padding(.top, Self.listGap)
        .padding(.bottom, 12)
      }
      .overlay {
        if model.workspace.projects.isEmpty {
          Text(t("sidebar.no-projects"))
            .font(.system(size: metrics.secondary))
            .foregroundStyle(theme.textTertiary)
        } else if shownProjects.isEmpty {
          Text(t("sidebar.nothing-matches"))
            .font(.system(size: metrics.secondary))
            .foregroundStyle(theme.textTertiary)
        }
      }
      // A drop that misses every project block still ends the drag, so the
      // indicator and the dragged id are cleared here.
      .onDrop(of: [.text], isTargeted: nil) { _ in
        endDrag()
        return false
      }
      SidebarFooter(
        worktreeCount: model.workspace.worktrees.count,
        terminalCount: model.workspace.sessions.count,
        theme: theme,
        metrics: metrics
      )
    }
    .background(theme.sidebarColor)
  }

  private func endDrag() {
    projectDropTarget = nil
    model.endProjectDrag()
  }

  private var filteredProjects: [SidebarFilter.Entry] {
    SidebarFilter(model.sidebarFilterText).apply(to: model.workspace)
  }

  /// The rows of one project's block, in the order its settings ask for.
  private func orderedWorktrees(
    of entry: SidebarFilter.Entry, sessions: WorktreeSessions
  ) -> [Worktree] {
    model.orderedWorktrees(entry.worktrees, in: entry.project, sessions: sessions)
  }
}
