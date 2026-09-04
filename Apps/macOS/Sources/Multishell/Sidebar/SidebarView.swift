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
      }
    }
    .padding(.horizontal, 8)
    .frame(height: (metrics.body * 1.85).rounded())
    .background(theme.rowHover, in: RoundedRectangle(cornerRadius: 6))
    .padding(.horizontal, 8)
    .padding(.bottom, 10)
  }

  /// Leaves room for the traffic lights; the title bar is hidden.
  private func header(_ theme: Theme) -> some View {
    HStack {
      Spacer()
      Button {
        Task { await model.chooseProject() }
      } label: {
        Image(systemName: "plus").font(.system(size: 13, weight: .medium))
      }
      .buttonStyle(.plain)
      .foregroundStyle(theme.textSecondary)
      .help("Add Project (⌘O)")
    }
    .padding(.horizontal, 14)
    .frame(height: 52)
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
    let visibleRows = 1 + (expanded ? worktrees.count : 0)
    let blockHeight =
      CGFloat(visibleRows) * metrics.rowHeight + CGFloat(visibleRows - 1) * Self.rowSpacing

    return VStack(spacing: Self.rowSpacing) {
      ProjectRow(
        project: project,
        isMissing: model.missingProjects.contains(project.id),
        theme: theme,
        metrics: metrics,
        toggle: { model.setExpanded(!project.isExpanded, for: project) },
        newWorktree: { model.newWorktreeProject = project }
      )
      .contextMenu { projectMenu(project) }
      .onDrag {
        draggingProject = project.id
        return NSItemProvider(object: project.id as NSString)
      }

      if expanded {
        ForEach(worktrees) { worktree in
          WorktreeRow(
            worktree: worktree,
            terminalCount: model.workspace.sessions(in: worktree.id).count,
            unseenActivity: model.unseenActivityCount(in: worktree.id) > 0,
            isSelected: model.workspace.selectedWorktreeID == worktree.id,
            status: model.statuses[worktree.id],
            theme: theme,
            metrics: metrics
          )
          .onTapGesture { model.select(worktree) }
          .contextMenu { worktreeMenu(worktree) }
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
        blockHeight: blockHeight,
        target: $dropTarget,
        perform: { edge in
          if let moving = draggingProject {
            model.moveProject(moving, edge, project.id)
          }
          endDrag()
        }
      ))
  }

  @ViewBuilder
  private func projectMenu(_ project: Project) -> some View {
    Button("New Worktree…") { model.newWorktreeProject = project }
    Button("Refresh") { Task { await model.refresh(project) } }
    Divider()
    Button("Project Settings…") {
      model.settingsProjectID = project.id
      openWindow(id: ProjectSettingsWindow.windowID)
    }
    Button("Reveal in Finder") { NSWorkspace.shared.activateFileViewerSelecting([project.path]) }
    Divider()
    Button("Remove Project", role: .destructive) { model.removeProject(project) }
  }

  @ViewBuilder
  private func worktreeMenu(_ worktree: Worktree) -> some View {
    Button("Reveal in Finder") { NSWorkspace.shared.activateFileViewerSelecting([worktree.path]) }
    Button("Copy Path") {
      NSPasteboard.general.clearContents()
      NSPasteboard.general.setString(worktree.path.path, forType: .string)
    }
    if !worktree.isPrimary {
      Divider()
      Button("Remove Worktree", role: .destructive) { model.requestRemoval(of: worktree) }
    }
  }
}

struct ProjectRow: View {
  let project: Project
  let isMissing: Bool
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

        Image(systemName: isMissing ? "folder.badge.questionmark" : "folder")
          .font(.system(size: metrics.icon))
          .foregroundStyle(theme.textSecondary)
          .help(project.path.path)

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
        .frame(width: 18, height: 20)
    }
    .buttonStyle(.plain)
    .help(help)
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
