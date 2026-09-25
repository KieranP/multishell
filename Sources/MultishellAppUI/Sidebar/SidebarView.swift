import MultishellAppCore
import MultishellCore
import SwiftUI

/// The project tree, drawn by hand: macOS 26 renders a `NavigationSplitView`
/// sidebar as a floating glass panel, and a `List` brings that styling too.
struct SidebarView: View {
  let model: AppModel

  @Environment(\.primaryButton) private var primaryButton
  @State private var dropTarget: ProjectDropTarget?
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
    let visible = visibleProjects
    VStack(spacing: 0) {
      SidebarHeader(
        isFiltering: model.showsSidebarFilter,
        theme: theme,
        toggleFilter: { model.setSidebarFilterOpen(!model.showsSidebarFilter) },
        addProject: { Task { await model.chooseProject() } }
      )
      if model.showsSidebarFilter {
        SidebarFilterField(
          filter: Bindable(model).sidebarFilterText, theme: theme, metrics: metrics,
          close: { model.setSidebarFilterOpen(false) })
      }
      ScrollView {
        LazyVStack(spacing: 1) {
          AgentsRow(
            counts: model.agentSidebarCounts,
            isSelected: model.showsAgentBoard,
            theme: theme,
            metrics: metrics,
            select: { model.showAgentBoard() }
          )
          .equatable()
          .padding(.bottom, 4)

          ProjectsHeader(model: model, theme: theme, metrics: metrics)

          ForEach(visible, id: \.project.id) { entry in
            projectRows(
              entry.project, worktrees: rows(of: entry, sessions: sessions),
              forcedOpen: entry.forcedOpen, sessions: sessions, theme: theme)
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
        } else if visible.isEmpty {
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
        sessionCount: model.workspace.sessions.count,
        theme: theme,
        metrics: metrics
      )
    }
    .background(theme.sidebarColor)
  }

  private func endDrag() {
    dropTarget = nil
    model.endProjectDrag()
  }

  private var visibleProjects: [SidebarFilter.Entry] {
    SidebarFilter(model.sidebarFilterText).apply(to: model.workspace)
  }

  /// The rows of one project's block, in the order its settings ask for.
  private func rows(of entry: SidebarFilter.Entry, sessions: WorktreeSessions) -> [Worktree] {
    model.ordered(entry.worktrees, in: entry.project, sessions: sessions)
  }

  /// A project and its worktrees move as one block, so the drop indicator
  /// spans the block: upper half means "before", lower half "after".
  private func projectRows(
    _ project: Project, worktrees: [Worktree], forcedOpen: Bool, sessions: WorktreeSessions,
    theme: Theme
  ) -> some View {
    let metrics = model.metrics
    let expanded = project.isExpanded || forcedOpen
    let visible = expanded ? worktrees : []

    return VStack(spacing: UIMetrics.sidebarRowSpacing) {
      projectRow(
        project, worktrees: worktrees, expanded: expanded, sessions: sessions, theme: theme,
        metrics: metrics)
      ForEach(visible) { worktree in
        worktreeRow(worktree, sessions: sessions, theme: theme, metrics: metrics)
        // Only the selected worktree's panes, so one set takes room at a time.
        if isSelected(worktree) {
          PaneRows(model: model, worktree: worktree, theme: theme, metrics: metrics)
        }
      }
    }
    .overlay(alignment: dropTarget?.edge == .bottom ? .bottom : .top) {
      if model.draggingProject != nil, let target = dropTarget, target.projectID == project.id {
        Capsule()
          .fill(Color.accentColor)
          .frame(height: 2)
          .padding(.horizontal, 4)
          .offset(y: target.edge == .top ? -1 : 1)
      }
    }
    .onDrop(
      of: [.text],
      delegate: ProjectDropDelegate(
        projectID: project.id,
        blockHeight: blockHeight(of: visible, metrics: metrics),
        target: $dropTarget,
        perform: { moving, edge in
          // `moveProject` looks the id up, so a drop carrying anything but a
          // project of ours moves nothing.
          if let moving { model.moveProject(moving, edge == .top ? .above : .below, project.id) }
          endDrag()
        }
      ))
  }

  private func isSelected(_ worktree: Worktree) -> Bool {
    !model.showsAgentBoard && model.workspace.selectedWorktreeID == worktree.id
  }

  private func blockHeight(of visible: [Worktree], metrics: UIMetrics) -> CGFloat {
    metrics.projectBlockHeight(
      worktreeRows: visible.map { worktree in
        (
          isNamed: model.customName(of: worktree) != nil,
          isRenaming: model.renamingWorktreeID == worktree.id,
          paneCount: isSelected(worktree)
            ? model.workspace.tabs(in: worktree.id).reduce(0) { $0 + $1.sessionIDs.count } : 0
        )
      })
  }

  private func projectRow(
    _ project: Project, worktrees: [Worktree], expanded: Bool, sessions: WorktreeSessions,
    theme: Theme, metrics: UIMetrics
  ) -> some View {
    ProjectRow(
      project: project,
      settings: model.effectiveSettings(for: project),
      isMissing: model.missingProjects.contains(project.id),
      // The worktree rows carry the dots while they are visible; the folder
      // stands in for them only once they are folded away.
      state: expanded ? nil : model.state(ofProject: project.id, sessions: sessions),
      worktreeCount: worktrees.count,
      isFetching: model.isFetching(project),
      theme: theme,
      metrics: metrics,
      toggle: { model.setExpanded(!project.isExpanded, for: project) },
      newWorktree: { model.requestNewWorktree(in: project) }
    )
    .equatable()
    .contextMenu { ProjectMenu(model: model, project: project) }
    .onDrag {
      dropTarget = nil
      model.beginProjectDrag(project.id)
      return NSItemProvider(object: project.id as NSString)
    }
    .dragConfiguration(.insideTheAppOnly)
    .onDragSessionUpdated { session in
      if case .ended = session.phase { endDrag() }
    }
    // The session's end reaches only a source still on screen.
    .onDisappear {
      model.projectDragSourceLeft(
        project.id, isPressed: { [primaryButton] in primaryButton.isDown })
    }
  }

  private func worktreeRow(
    _ worktree: Worktree, sessions: WorktreeSessions, theme: Theme, metrics: UIMetrics
  ) -> some View {
    WorktreeRow(
      worktree: worktree,
      customName: model.customName(of: worktree),
      isRenaming: model.renamingWorktreeID == worktree.id,
      terminalCount: sessions[worktree.id].count,
      state: model.state(ofWorktree: worktree.id, sessions: sessions),
      operation: model.worktreeOperations[worktree.id],
      isSelected: isSelected(worktree),
      isDropTarget: tabDropTarget == worktree.id,
      status: model.statuses[worktree.id],
      mergeState: model.mergeState(of: worktree),
      theme: theme,
      metrics: metrics,
      beginRename: { model.beginRenaming(worktree) },
      commit: { model.commitRename(of: worktree.id, to: $0) },
      cancel: { model.cancelRenaming() }
    )
    .equatable()
    .onTapGesture { model.select(worktree) }
    .contextMenu { WorktreeActions(model: model, worktree: worktree) }
    // A tab dragged from the strip lands here. The type is the tab's own,
    // so a project dragged past is not offered this row.
    .onDrop(
      of: [TabTransfer.contentType],
      delegate: WorktreeTabDropDelegate(
        worktreeID: worktree.id,
        target: $tabDropTarget,
        takes: { model.worktreeRowTakesDraggedTab($0) },
        drop: { model.dropDraggedTab(on: .worktree($0)) })
    )
  }
}
