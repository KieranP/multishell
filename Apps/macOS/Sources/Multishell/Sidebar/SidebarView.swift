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
          Text("Projects")
            .font(.system(size: metrics.caption, weight: .semibold))
            .foregroundStyle(theme.textTertiary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 8)
            .frame(height: 22)
            .padding(.bottom, 2)

          ForEach(visibleProjects, id: \.project.id) { entry in
            projectRows(entry.project, worktrees: entry.worktrees, theme: theme)
          }
        }
        .padding(.horizontal, 8)
        .padding(.bottom, 12)
      }
      .overlay {
        if model.workspace.projects.isEmpty {
          Text("No projects yet")
            .font(.system(size: metrics.secondary))
            .foregroundStyle(theme.textTertiary)
        } else if visibleProjects.isEmpty {
          Text("Nothing matches")
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

  private var isFiltering: Bool {
    SidebarFilter(filter).isActive
  }

  private func filterField(_ theme: Theme, metrics: UIMetrics) -> some View {
    HStack(spacing: 6) {
      Image(systemName: "magnifyingglass")
        .font(.system(size: metrics.icon, weight: .semibold))
        .foregroundStyle(theme.textTertiary)
      TextField("Filter", text: $filter)
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
        .accessibilityLabel("Clear filter")
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
      .help("Add Project (⌘O)")
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
        "\(worktrees) worktree\(worktrees == 1 ? "" : "s") · \(sessions) terminal\(sessions == 1 ? "" : "s")"
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
    // A renamed worktree's row is two lines tall, so the drop's halfway
    // point cannot be counted off one row height.
    let blockHeight =
      visible.reduce(metrics.rowHeight) { total, worktree in
        let tall =
          model.customName(of: worktree) != nil || model.renamingWorktreeID == worktree.id
        return total + Self.rowSpacing + (tall ? metrics.namedRowHeight : metrics.rowHeight)
      }

    return VStack(spacing: Self.rowSpacing) {
      ProjectRow(
        project: project,
        settings: model.effectiveSettings(for: project),
        isMissing: model.missingProjects.contains(project.id),
        // The worktree rows carry the dots while they are visible; the folder
        // stands in for them only once they are folded away.
        state: expanded ? nil : model.state(ofProject: project.id),
        worktreeCount: worktrees.count,
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

      ForEach(visible) { worktree in
        WorktreeRow(
          worktree: worktree,
          customName: model.customName(of: worktree),
          isRenaming: model.renamingWorktreeID == worktree.id,
          terminalCount: model.workspace.sessions(in: worktree.id).count,
          state: model.state(ofWorktree: worktree.id),
          operation: model.worktreeOperations[worktree.id],
          isSelected: model.workspace.selectedWorktreeID == worktree.id,
          status: model.statuses[worktree.id],
          theme: theme,
          metrics: metrics,
          beginRename: { model.beginRenaming(worktree) },
          commit: { model.commitRename(of: worktree.id, to: $0) },
          cancel: { model.cancelRenaming() }
        )
        .onTapGesture { model.select(worktree) }
        .contextMenu { worktreeMenu(worktree) }
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
        blockHeight: blockHeight,
        target: $dropTarget,
        perform: { edge in
          if let moving = draggingProject {
            model.moveProject(moving, edge == .top ? .above : .below, project.id)
          }
          endDrag()
        }
      ))
  }

  @ViewBuilder
  private func projectMenu(_ project: Project) -> some View {
    Button("New Worktree…") { model.requestNewWorktree(in: project) }
    Button("Refresh") { Task { await model.refreshRequested(project) } }
    Divider()
    Button("Project Settings…") {
      model.settingsProjectID = project.id
      openWindow(id: ProjectSettingsWindow.windowID)
    }
    Button("Reveal in Finder") { model.revealInFileBrowser(project.path) }
    Divider()
    Button("Remove Project…", role: .destructive) {
      model.requestProjectRemoval(project, from: .workspace)
    }
  }

  @ViewBuilder
  private func worktreeMenu(_ worktree: Worktree) -> some View {
    WorktreeActions(model: model, worktree: worktree)
  }
}

struct ProjectRow: View {
  let project: Project
  /// The project's settings with its repository's own filled in, for the
  /// icon.
  let settings: ProjectSettings
  let isMissing: Bool
  let state: SessionState?
  let worktreeCount: Int
  let theme: Theme
  let metrics: UIMetrics
  let toggle: () -> Void
  let newWorktree: () -> Void

  @State private var isHovered = false

  var body: some View {
    HStack(spacing: 6) {
      // Only the chevron, icon and name toggle. A row-wide target made a
      // slightly-missed click on the + collapse the project instead.
      HStack(spacing: 6) {
        Image(systemName: "chevron.right")
          .font(.system(size: metrics.badge - 1, weight: .bold))
          .rotationEffect(.degrees(project.isExpanded ? 90 : 0))
          .foregroundStyle(theme.textTertiary)
          .frame(width: 10)
          .help(project.isExpanded ? "Collapse" : "Expand")

        if let state {
          Circle()
            .fill(theme.color(for: state))
            .frame(width: 7, height: 7)
            .frame(width: metrics.icon + 6)
            .help("\(state.displayName) in a terminal of a collapsed worktree")
        } else {
          ProjectIconView(
            settings: settings, isMissing: isMissing, theme: theme, size: metrics.icon
          )
          .help(project.path.path)
        }

        Text(project.name)
          .font(.system(size: metrics.body, weight: .medium))
          .foregroundStyle(theme.textPrimary)
          .lineLimit(1)
          .opacity(isMissing ? 0.5 : 1)
          .help(isMissing ? "\(project.path.path) is not reachable right now" : "")
      }
      .frame(height: metrics.rowHeight)
      .contentShape(.rect)
      .onTapGesture(perform: toggle)
      .accessibilityElement(children: .ignore)
      .accessibilityLabel(
        AccessibilityText.project(
          name: project.name, isExpanded: project.isExpanded, isMissing: isMissing, state: state,
          worktreeCount: worktreeCount)
      )
      .accessibilityAddTraits(.isButton)
      .accessibilityAction(named: project.isExpanded ? "Collapse" : "Expand", toggle)

      Spacer(minLength: 4)

      rowButton("plus", help: "New Worktree", action: newWorktree)
    }
    .padding(.horizontal, 8)
    .frame(height: metrics.rowHeight)
    .onHover { isHovered = $0 }
  }

  private func rowButton(_ symbol: String, help: String, action: @escaping () -> Void) -> some View
  {
    Button(action: action) {
      Image(systemName: symbol)
        .font(.system(size: metrics.icon))
        .foregroundStyle(isHovered ? theme.textSecondary : theme.textTertiary)
        .frame(width: 24, height: 24)
        .contentShape(.rect)
    }
    .buttonStyle(.plain)
    .help(help)
    .accessibilityLabel(help)
  }
}

struct ProjectDropTarget: Equatable {
  let projectID: Project.ID
  let edge: VerticalEdge
}

/// Tracks the pointer over a project block so the sidebar can draw the
/// insertion line, and performs the move on release. The dragged id lives in
/// the sidebar's state, set when the drag starts, so no item provider has to
/// be decoded asynchronously here.
struct ProjectDropDelegate: DropDelegate {
  let projectID: Project.ID
  let blockHeight: CGFloat
  @Binding var target: ProjectDropTarget?
  let perform: (VerticalEdge) -> Void

  func validateDrop(info: DropInfo) -> Bool {
    info.hasItemsConforming(to: [.text])
  }

  func dropEntered(info: DropInfo) {
    target = ProjectDropTarget(projectID: projectID, edge: edge(for: info))
  }

  func dropUpdated(info: DropInfo) -> DropProposal? {
    target = ProjectDropTarget(projectID: projectID, edge: edge(for: info))
    return DropProposal(operation: .move)
  }

  func dropExited(info: DropInfo) {
    if target?.projectID == projectID { target = nil }
  }

  func performDrop(info: DropInfo) -> Bool {
    let edge = edge(for: info)
    target = nil
    perform(edge)
    Task { @MainActor [$target] in $target.wrappedValue = nil }
    return true
  }

  private func edge(for info: DropInfo) -> VerticalEdge {
    info.location.y < blockHeight / 2 ? .top : .bottom
  }
}
