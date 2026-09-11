import MultishellAppCore
import MultishellCore
import SwiftUI

/// The project tree, drawn by hand.
///
/// macOS 26 renders `NavigationSplitView` sidebars as a floating glass panel
/// inset from the window, which is not the edge-to-edge look this app has.
/// A `List` inside a plain container still brings that styling with it, so
/// the rows are plain views and selection is painted here.
struct SidebarView: View {
  let model: AppModel

  @State private var draggingProject: Project.ID?
  @State private var dropTarget: ProjectDropTarget?
  /// The worktree a dragged tab is hovering over, drawn on its row.
  @State private var tabDropTarget: Worktree.ID?
  @State private var filter = ""
  @Environment(\.openWindow) private var openWindow

  private static let rowSpacing: CGFloat = 1

  var body: some View {
    let theme = model.currentTheme
    let metrics = model.metrics
    VStack(spacing: 0) {
      header(theme)
      filterField(theme, metrics: metrics)
      ScrollView {
        LazyVStack(spacing: 1) {
          AgentsRow(
            counts: model.agentSidebarCounts,
            isSelected: model.showsAgentBoard,
            theme: theme,
            metrics: metrics,
            select: { model.showAgentBoard() }
          )
          .padding(.bottom, 4)

          Text(t("sidebar.projects"))
            .font(.system(size: metrics.caption, weight: .semibold))
            .foregroundStyle(theme.textTertiary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 8)
            .frame(height: 22)
            .padding(.bottom, 2)

          ForEach(visibleProjects, id: \.project.id) { entry in
            projectRows(entry.project, worktrees: rows(of: entry), theme: theme)
          }
        }
        .padding(.horizontal, 8)
        .padding(.bottom, 12)
      }
      .overlay {
        if model.workspace.projects.isEmpty {
          Text(t("sidebar.no-projects"))
            .font(.system(size: metrics.secondary))
            .foregroundStyle(theme.textTertiary)
        } else if visibleProjects.isEmpty {
          Text(t("sidebar.nothing-matches"))
            .font(.system(size: metrics.secondary))
            .foregroundStyle(theme.textTertiary)
        }
      }
      // A drop that misses every project block still ends the drag, so
      // the indicator and the dragged id are cleared here rather than
      // left over for the next render.
      .onDrop(of: [.text], isTargeted: nil) { _ in
        endDrag()
        return false
      }
      footer(theme)
    }
    .background(theme.sidebarColor)
  }

  private func endDrag() {
    dropTarget = nil
    draggingProject = nil
  }

  private var visibleProjects: [SidebarFilter.Entry] {
    SidebarFilter(filter).apply(to: model.workspace)
  }

  /// The rows of one project's block, in the order its settings ask for.
  private func rows(of entry: SidebarFilter.Entry) -> [Worktree] {
    model.ordered(entry.worktrees, in: entry.project)
  }

  private var isFiltering: Bool {
    SidebarFilter(filter).isActive
  }

  private func filterField(_ theme: Theme, metrics: UIMetrics) -> some View {
    HStack(spacing: 6) {
      Image(systemName: "magnifyingglass")
        .font(.system(size: metrics.icon, weight: .semibold))
        .foregroundStyle(theme.textTertiary)
      TextField(t("sidebar.filter"), text: $filter)
        .textFieldStyle(.plain)
        .font(.system(size: metrics.secondary))
        .foregroundStyle(theme.textPrimary)
        .onExitCommand { filter = "" }
      if isFiltering {
        Button {
          filter = ""
        } label: {
          Image(systemName: "xmark.circle.fill")
            .font(.system(size: metrics.icon))
            .foregroundStyle(theme.textTertiary)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(t("sidebar.clear-filter"))
      }
    }
    .padding(.horizontal, 8)
    .frame(height: (metrics.body * 1.85).rounded())
    .background(theme.rowHover, in: RoundedRectangle(cornerRadius: 6))
    .padding(.horizontal, 8)
    .padding(.bottom, 10)
  }

  /// Leaves room for the traffic lights; the title bar is hidden. The
  /// folder-plus, not a bare plus: the project row's + is New Worktree and
  /// the tab strip's is New Tab, and three identical glyphs read as one.
  private func header(_ theme: Theme) -> some View {
    HStack {
      Spacer()
      Button {
        Task { await model.chooseProject() }
      } label: {
        Image(systemName: "folder.badge.plus")
          .font(.system(size: 13, weight: .medium))
          .frame(width: 28, height: 28)
          .contentShape(.rect)
      }
      .buttonStyle(.plain)
      .foregroundStyle(theme.textSecondary)
      .help(t("sidebar.add-project"))
    }
    .padding(.horizontal, 14)
    .frame(height: UIMetrics.headerHeight)
    .titleBarDoubleClick()
  }

  private func footer(_ theme: Theme) -> some View {
    let worktrees = model.workspace.worktrees.count
    let sessions = model.workspace.sessions.count
    return HStack {
      Text(
        t("sidebar.counts", t("count.worktrees", worktrees), t("count.terminals", sessions))
      )
      .font(.system(size: model.metrics.caption))
      .foregroundStyle(theme.textTertiary)
      Spacer()
    }
    .padding(.horizontal, 14)
    .frame(height: 30)
    .overlay(alignment: .top) { theme.hairline.frame(height: 0.5) }
  }

  /// A project and its worktrees move as one block, so the drop indicator
  /// spans the block: upper half means "before", lower half "after".
  private func projectRows(_ project: Project, worktrees: [Worktree], theme: Theme) -> some View {
    let metrics = model.metrics
    let expanded = project.isExpanded || isFiltering
    let visible = expanded ? worktrees : []

    return VStack(spacing: Self.rowSpacing) {
      projectRow(project, worktrees: worktrees, expanded: expanded, theme: theme, metrics: metrics)
      ForEach(visible) { worktreeRow($0, theme: theme, metrics: metrics) }
    }
    .overlay(alignment: dropTarget?.edge == .bottom ? .bottom : .top) {
      if draggingProject != nil, let target = dropTarget, target.projectID == project.id {
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
        perform: { edge in
          if let moving = draggingProject {
            model.moveProject(moving, edge == .top ? .above : .below, project.id)
          }
          endDrag()
        }
      ))
  }

  /// How tall a project's whole block is, which is what the drop delegate
  /// halves to decide before from after. Counted off the same
  /// `worktreeRowHeight` the rows draw themselves at, and asking each
  /// worktree rather than multiplying: a named or renaming row is two lines
  /// tall, and a block measured as if every row were one puts the indicator
  /// in the wrong half.
  private func blockHeight(of visible: [Worktree], metrics: UIMetrics) -> CGFloat {
    visible.reduce(metrics.rowHeight) { total, worktree in
      total + Self.rowSpacing
        + metrics.worktreeRowHeight(
          isNamed: model.customName(of: worktree) != nil,
          isRenaming: model.renamingWorktreeID == worktree.id)
    }
  }

  private func projectRow(
    _ project: Project, worktrees: [Worktree], expanded: Bool, theme: Theme, metrics: UIMetrics
  ) -> some View {
    ProjectRow(
      project: project,
      settings: model.effectiveSettings(for: project),
      isMissing: model.missingProjects.contains(project.id),
      // The worktree rows carry the dots while they are visible; the folder
      // stands in for them only once they are folded away.
      state: expanded ? nil : model.state(ofProject: project.id),
      worktreeCount: worktrees.count,
      isFetching: model.isFetching(project),
      theme: theme,
      metrics: metrics,
      toggle: { model.setExpanded(!project.isExpanded, for: project) },
      newWorktree: { model.requestNewWorktree(in: project) }
    )
    .contextMenu { projectMenu(project) }
    .onDrag {
      draggingProject = project.id
      return NSItemProvider(object: project.id as NSString)
    }
  }

  private func worktreeRow(
    _ worktree: Worktree, theme: Theme, metrics: UIMetrics
  ) -> some View {
    WorktreeRow(
      worktree: worktree,
      customName: model.customName(of: worktree),
      isRenaming: model.renamingWorktreeID == worktree.id,
      terminalCount: model.workspace.sessions(in: worktree.id).count,
      state: model.state(ofWorktree: worktree.id),
      operation: model.worktreeOperations[worktree.id],
      isSelected: !model.showsAgentBoard && model.workspace.selectedWorktreeID == worktree.id,
      isDropTarget: tabDropTarget == worktree.id,
      status: model.statuses[worktree.id],
      mergeState: model.mergeState(of: worktree),
      theme: theme,
      metrics: metrics,
      beginRename: { model.beginRenaming(worktree) },
      commit: { model.commitRename(of: worktree.id, to: $0) },
      cancel: { model.cancelRenaming() }
    )
    .onTapGesture { model.select(worktree) }
    .contextMenu { WorktreeActions(model: model, worktree: worktree) }
    // A tab dragged from the strip lands here. The type is the tab's own,
    // so a project being dragged past on its way to a new place in the
    // sidebar is not offered this row at all.
    .dropDestination(for: TabTransfer.self) { dropped, _ in
      tabDropTarget = nil
      // Refused here, and only here, so the drag springs back where the
      // answer is plainly no: an unknown tab, or the row it already sits
      // under. The rest of what can stop a move — either end busy with a
      // create or a remove, a directory that has gone — says so with an
      // alert of its own rather than a silent spring-back.
      guard let moving = dropped.first?.id, let tab = model.workspace.tab(moving),
        tab.worktreeID != worktree.id
      else { return false }
      // A turn later, so the drag is over before the tab leaves the strip
      // it was dragged from; see `TabDropDelegate`. This drop moves the
      // selection too, so it is the one where the preview had furthest to
      // hunt for a view that had gone.
      Task { @MainActor in model.moveTab(moving, to: worktree.id) }
      return true
    } isTargeted: { isTargeted in
      if isTargeted {
        tabDropTarget = worktree.id
      } else if tabDropTarget == worktree.id {
        tabDropTarget = nil
      }
    }
  }

  @ViewBuilder
  private func projectMenu(_ project: Project) -> some View {
    Button(t("actions.new-worktree")) { model.requestNewWorktree(in: project) }
    Button(t("action.refresh")) { Task { await model.refreshRequested(project) } }
    // Refresh asks git what is on disk; Fetch asks the remote, which is
    // what the merged badges are measured against.
    Button(t("actions.fetch")) { Task { await model.fetch(project) } }
      .disabled(model.isFetching(project))
    Divider()
    Button(t("actions.project-settings")) {
      model.settingsProjectID = project.id
      openWindow(id: ProjectSettingsWindow.windowID)
    }
    Button(t("action.reveal-in-finder")) { model.revealInFileBrowser(project.path) }
    Divider()
    Button(t("actions.remove-project"), role: .destructive) {
      model.requestProjectRemoval(project, from: .workspace)
    }
  }
}
