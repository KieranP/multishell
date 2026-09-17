import MultishellAppCore
import MultishellCore
import SwiftUI

/// The project tree, drawn by hand: macOS 26 renders a `NavigationSplitView`
/// sidebar as a floating glass panel, and a `List` brings that styling too.
struct SidebarView: View {
  let model: AppModel

  @State private var draggingProject: Project.ID?
  @State private var dropTarget: ProjectDropTarget?
  /// The worktree a dragged tab is hovering over, drawn on its row.
  @State private var tabDropTarget: Worktree.ID?
  @State private var filter = ""
  /// The filter field is folded away until asked for; it is wanted rarely.
  @State private var isFiltering = false
  @FocusState private var filterFocused: Bool
  @State private var sortHovered = false
  @Environment(\.openWindow) private var openWindow

  private static let rowSpacing: CGFloat = 1
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
      header(theme)
      if isFiltering { filterField(theme, metrics: metrics) }
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

          projectsHeader(theme, metrics: metrics)

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
  private func rows(of entry: SidebarFilter.Entry, sessions: WorktreeSessions) -> [Worktree] {
    model.ordered(entry.worktrees, in: entry.project, sessions: sessions)
  }

  /// Closing clears the filter, a field folded away being unable to say why
  /// rows are missing, and hands the keyboard back rather than dropping it.
  private func setFiltering(_ wanted: Bool) {
    isFiltering = wanted
    guard !wanted else { return }
    filter = ""
    model.focusActivePane()
  }

  private func filterField(_ theme: Theme, metrics: UIMetrics) -> some View {
    HStack(spacing: 6) {
      TextField(t("sidebar.filter"), text: $filter)
        .textFieldStyle(.plain)
        .font(.system(size: metrics.secondary))
        .foregroundStyle(theme.textPrimary)
        .focused($filterFocused)
        // A turn later: focus does not take on a field the hierarchy has not
        // installed yet.
        .task { filterFocused = true }
        .onExitCommand { setFiltering(false) }
      if SidebarFilter(filter).isActive {
        Button {
          filter = ""
          filterFocused = true
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
  }

  /// Leaves room for the traffic lights, the title bar being hidden. The
  /// folder-plus, three identical glyphs otherwise reading as one.
  private func header(_ theme: Theme) -> some View {
    HStack(spacing: 2) {
      Spacer()
      Button {
        setFiltering(!isFiltering)
      } label: {
        Image(systemName: "magnifyingglass")
          .font(.system(size: 13, weight: .medium))
          .frame(width: 28, height: 28)
          .contentShape(.rect)
      }
      .buttonStyle(.plain)
      .foregroundStyle(isFiltering ? theme.textPrimary : theme.textSecondary)
      .help(t("sidebar.filter-projects"))
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

  /// The Projects label, with the sort menu at the + column's edge so the
  /// setting sits beside the rows it orders. Its width is a row button's.
  private func projectsHeader(_ theme: Theme, metrics: UIMetrics) -> some View {
    HStack(spacing: 6) {
      Text(t("sidebar.projects"))
        .font(.system(size: metrics.caption, weight: .semibold))
        .foregroundStyle(theme.textTertiary)
      Spacer(minLength: 4)
      sortMenu(theme, metrics: metrics)
    }
    .padding(.horizontal, 8)
    .frame(height: 22)
    .padding(.bottom, 2)
  }

  /// The global order and the active-first toggle; a project's override
  /// stays in its settings. See docs/design/worktrees.md.
  private func sortMenu(_ theme: Theme, metrics: UIMetrics) -> some View {
    Menu {
      Picker(
        t("sidebar.sort-worktrees"),
        selection: model.setting(\.worktreeSortOrder, write: model.setWorktreeSortOrder)
      ) {
        ForEach(WorktreeSortOrder.allCases, id: \.self) { Text($0.displayName).tag($0) }
      }
      .pickerStyle(.inline)
      Divider()
      Toggle(
        t("worktrees.active-first"),
        isOn: model.setting(
          \.showsActiveWorktreesFirst, write: model.setShowsActiveWorktreesFirst))
    } label: {
      Image(systemName: "arrow.up.arrow.down")
        .font(.system(size: metrics.badge))
        .foregroundStyle(sortHovered ? theme.textSecondary : theme.textTertiary.opacity(0.7))
        .frame(width: 24, height: 22)
        // Painted: a menu is hit-tested by its label's ink, and the glyph
        // alone is a small target. As the strip's + does.
        .background(theme.sidebarColor)
        .contentShape(.rect)
    }
    // Not `.borderlessButton`: that AppKit button draws the image at its own
    // size and tint, so no font or colour set here reaches it.
    .menuStyle(.button)
    .buttonStyle(.plain)
    .menuIndicator(.hidden)
    .fixedSize()
    .onHover { sortHovered = $0 }
    .help(t("sidebar.sort-worktrees"))
    .accessibilityLabel(t("sidebar.sort-worktrees"))
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
  private func projectRows(
    _ project: Project, worktrees: [Worktree], forcedOpen: Bool, sessions: WorktreeSessions,
    theme: Theme
  ) -> some View {
    let metrics = model.metrics
    let expanded = project.isExpanded || forcedOpen
    let visible = expanded ? worktrees : []

    return VStack(spacing: Self.rowSpacing) {
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

  /// How tall a project's block is, which the drop delegate halves: each
  /// worktree's row, two lines when named, plus the selected one's pane rows.
  private func blockHeight(of visible: [Worktree], metrics: UIMetrics) -> CGFloat {
    visible.reduce(metrics.rowHeight) { total, worktree in
      let panes =
        isSelected(worktree)
        ? model.workspace.tabs(in: worktree.id).reduce(0) { $0 + $1.sessionIDs.count } : 0
      return total + Self.rowSpacing
        + metrics.worktreeRowHeight(
          isNamed: model.customName(of: worktree) != nil,
          isRenaming: model.renamingWorktreeID == worktree.id)
        + CGFloat(panes) * (metrics.paneRowHeight + Self.rowSpacing)
    }
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
    .contextMenu { projectMenu(project) }
    .onDrag {
      draggingProject = project.id
      return NSItemProvider(object: project.id as NSString)
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
    .onTapGesture { model.select(worktree) }
    .contextMenu { WorktreeActions(model: model, worktree: worktree) }
    // A tab dragged from the strip lands here. The type is the tab's own,
    // so a project dragged past is not offered this row.
    .dropDestination(for: TabTransfer.self) { dropped, _ in
      tabDropTarget = nil
      // A fifth drop path, so it ends the drag as the four in `TabDrops` do:
      // a drag left open keeps an overlay over every pane.
      model.tabDrag.end()
      // Refused here only where the answer is plainly no. The rest of what
      // can stop a move says so with an alert of its own.
      guard let moving = dropped.first?.id, let tab = model.workspace.tab(moving),
        tab.worktreeID != worktree.id
      else { return false }
      // A turn later, so the drag is over before the tab leaves the strip;
      // see `TabDropDelegate`. This drop moves the selection too.
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
