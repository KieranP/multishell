import MultishellAppCore
import MultishellCore
import SwiftUI
import UniformTypeIdentifiers

/// A project and its worktrees move as one block, so the drop indicator
/// spans the block: upper half means "before", lower half "after".
struct ProjectBlock: View {
  let model: AppModel
  let project: Project
  /// The rows of the block, in the order its settings ask for.
  let worktrees: [Worktree]
  /// What the chevron shows, the filter's word over the project's own.
  let isExpanded: Bool
  let sessions: WorktreeSessions
  let theme: Theme
  @Binding var projectDropTarget: ProjectDropTarget?
  @Binding var tabDropTarget: Worktree.ID?
  let endProjectDrag: () -> Void

  var body: some View {
    let metrics = model.metrics
    let rows = isExpanded ? worktrees.map(model.sidebarWorktree) : []

    VStack(spacing: UIMetrics.sidebarRowSpacing) {
      projectRow(metrics: metrics)
      ForEach(rows) { row in
        worktreeRow(row, metrics: metrics)
        if !row.panes.isEmpty {
          SelectedWorktreePanes(model: model, panes: row.panes, theme: theme, metrics: metrics)
        }
      }
    }
    .overlay(alignment: projectDropTarget?.placement == .below ? .bottom : .top) {
      if model.draggedProjectID != nil, let target = projectDropTarget,
        target.projectID == project.id
      {
        InsertionLine(axis: .horizontal, isAfter: target.placement != .above)
      }
    }
    .onDrop(
      of: [.text],
      delegate: ProjectBlockDropDelegate(
        projectID: project.id,
        blockHeight: metrics.projectBlockHeight(worktreeRows: rows),
        target: $projectDropTarget,
        drop: { moving, placement in
          // `moveProject` looks the id up, so a drop carrying anything but a
          // project of ours moves nothing.
          if let moving { model.moveProject(moving, placement, project.id) }
          endProjectDrag()
        }
      ))
  }

  private func projectRow(metrics: UIMetrics) -> some View {
    ProjectRow(
      project: project,
      isExpanded: isExpanded,
      settings: model.effectiveSettings(for: project),
      isMissing: model.missingProjects.contains(project.id),
      // The worktree rows carry the dots while they are visible; the folder
      // stands in for them only once they are folded away.
      state: isExpanded ? nil : model.state(ofProject: project.id, sessions: sessions),
      worktreeCount: worktrees.count,
      isFetching: model.isFetching(project),
      theme: theme,
      metrics: metrics,
      toggle: { model.toggleExpansion(of: project) },
      newWorktree: { model.requestNewWorktree(in: project) }
    )
    .equatable()
    .contextMenu { ProjectActions(model: model, project: project) }
    .inAppDragSource(
      begin: {
        projectDropTarget = nil
        model.beginProjectDrag(project.id)
        return NSItemProvider(object: project.id as NSString)
      },
      ended: endProjectDrag,
      sourceLeft: { model.projectDragSourceLeft(project.id, isPressed: $0) }
    )
  }

  private func worktreeRow(_ row: SidebarWorktree, metrics: UIMetrics) -> some View {
    let worktree = row.worktree
    return WorktreeRow(
      worktree: worktree,
      customName: row.customName,
      isRenaming: row.isRenaming,
      terminalCount: sessions[worktree.id].count,
      state: model.state(ofWorktree: worktree.id, sessions: sessions),
      operation: model.worktreeOperations[worktree.id],
      isSelected: model.isInView(worktree),
      isDropTarget: tabDropTarget == worktree.id,
      status: model.statuses[worktree.id],
      mergeState: model.mergeState(of: worktree),
      theme: theme,
      metrics: metrics,
      beginRename: { model.beginRenamingWorktree(worktree) },
      commitRename: { model.commitWorktreeRename(of: worktree.id, to: $0) },
      cancelRename: { model.cancelRenamingWorktree() }
    )
    .equatable()
    .onTapGesture { model.select(worktree) }
    .contextMenu { WorktreeActions(model: model, worktree: worktree) }
    // A tab dragged from the strip lands here. The type is the tab's own,
    // so a project dragged past is not offered this row.
    .onDrop(
      of: [TabTransfer.contentType],
      delegate: WorktreeRowDropDelegate(
        worktreeID: worktree.id,
        target: $tabDropTarget,
        takes: { model.worktreeRowTakesDraggedTab($0) },
        drop: { model.dropDraggedTab(on: .worktree($0)) })
    )
  }
}
