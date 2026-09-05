import AppKit
import MultishellCore
import MultishellGitKit
import SwiftUI

// MARK: - Projects

extension AppModel {
  func chooseProject() async {
    let panel = NSOpenPanel()
    panel.canChooseDirectories = true
    panel.canChooseFiles = false
    panel.allowsMultipleSelection = false
    panel.prompt = "Add Project"

    guard panel.runModal() == .OK, let url = panel.url else { return }
    await addProject(at: url)
  }

  func addProject(at url: URL) async {
    guard let worktrees else { return }
    guard await worktrees.isRepository(url) else {
      presentedError = PresentedError(
        title: "Not a git repository",
        message: "\(url.lastPathComponent) has no .git directory, or git could not read it."
      )
      return
    }
    // A subdirectory or a linked worktree is the same repository; adding it
    // as its own project would list the same worktrees twice.
    let root = (try? await worktrees.repositoryRoot(containing: url)) ?? url
    let project = store.addProject(at: root)
    await refresh(project)
    await rearmWatcher()
  }

  /// Entry point from the UI. Always asks: removal closes every live
  /// terminal in the project's worktrees, with no undo.
  func requestProjectRemoval(_ project: Project, from source: PendingProjectRemoval.Source) {
    pendingProjectRemoval = PendingProjectRemoval(project: project, source: source)
  }

  /// What the confirmation says, with the live terminal count.
  func projectRemovalMessage(for project: Project) -> String {
    let live = workspace.worktrees(of: project.id).map { liveTerminalCount(in: $0.id) }
    return PendingProjectRemoval.message(liveTerminals: live.reduce(0, +))
  }

  func removeProject(_ project: Project) {
    commonGitDirectories[project.id] = nil
    worktreeRecords[project.id] = nil
    store.removeProject(project.id)
    sync()
    Task { await rearmWatcher() }
  }

  /// Moves `id` to sit just above or just below `target`.
  func moveProject(_ id: Project.ID, _ edge: VerticalEdge, _ target: Project.ID) {
    let projects = workspace.projects
    guard
      let from = projects.firstIndex(where: { $0.id == id }),
      let anchor = projects.firstIndex(where: { $0.id == target }),
      from != anchor
    else { return }
    let destination = edge == .top ? anchor : anchor + 1
    store.moveProjects(from: IndexSet(integer: from), to: destination)
  }

  func setExpanded(_ expanded: Bool, for project: Project) {
    store.setExpanded(expanded, forProject: project.id)
  }

  func updateSettings(_ settings: ProjectSettings, for project: Project) {
    store.updateSettings(settings, forProject: project.id)
  }

  /// Refresh chosen by the user. A failure already shown for this project is
  /// shown again: the click asked for an answer.
  func refreshRequested(_ project: Project) async {
    missingProjects.remove(project.id)
    await refresh(project)
  }

  func refresh(_ project: Project) async {
    guard let worktrees else { return }
    let path = project.path.path
    guard await Self.offMain({ FileManager.default.fileExists(atPath: path) }) else {
      missingProjects.insert(project.id)
      return
    }
    // Read before the list so a change landing in between is caught by the
    // next tick rather than lost.
    var records: WorktreeRecords?
    if let common = await commonGitDirectory(of: project) {
      records = await Self.offMain { WorktreeRecords.read(commonDirectory: common) }
    }
    do {
      let discovered = try await worktrees.refresh(project)
      // Removed while git ran: the store ignores the list, and the records
      // and directory cached above must not come back for it either.
      guard workspace.project(project.id) != nil else {
        commonGitDirectories[project.id] = nil
        return
      }
      store.replaceWorktrees(discovered, forProject: project.id)
      worktreeRecords[project.id] = records
      missingProjects.remove(project.id)
    } catch {
      // Every watcher tick and every return to the foreground refreshes a
      // project git cannot read, so the alert goes up on the first failure
      // only; the row stays dimmed until a refresh succeeds.
      if missingProjects.insert(project.id).inserted { report(error) }
    }
  }
}

// MARK: - Worktrees

extension AppModel {
  /// A worktree with no tabs gets one, unless the setting says selecting
  /// should only show the worktree and leave the first shell to Cmd+T or
  /// the actions menu. `openingFirstTab: false` is for a caller about to
  /// open its own tab. Returns false when the directory is gone and nothing
  /// was selected, so that caller does not act on whatever was selected.
  @discardableResult
  func select(_ worktree: Worktree, openingFirstTab: Bool = true) -> Bool {
    guard directoryExists(of: worktree) else { return false }
    store.selectWorktree(worktree.id)
    warmWorktrees.insert(worktree.id)
    if openingFirstTab, workspace.tabs(in: worktree.id).isEmpty, workspace.opensTerminalOnSelect {
      openFirstOrNewTab(in: worktree)
    }
    sync()
    return true
  }

  /// A shell spawned in a missing directory silently lands in $HOME, which
  /// is worse than an honest refusal. Checked before anything that starts a
  /// shell: selecting, a new tab, a split.
  func directoryExists(of worktree: Worktree) -> Bool {
    if FileManager.default.fileExists(atPath: worktree.path.path) { return true }
    presentedError = PresentedError(
      title: "Worktree directory is missing",
      message:
        "\(worktree.path.path) does not exist. If it was deleted by hand, remove the worktree to let git prune it."
    )
    return false
  }

  /// Opens the sheet for `project`, or for the project the workspace is
  /// working in when none is given: the selected worktree's, or the only one.
  /// With several projects and nothing selected the picker starts blank.
  func requestNewWorktree(in project: Project? = nil) {
    newWorktreeRequest = NewWorktreeRequest(projectID: (project ?? activeProject)?.id)
  }

  func plannedPath(forBranch branch: String, createBranch: Bool, in project: Project) -> URL? {
    worktrees?.plannedPath(
      forBranch: branch, createBranch: createBranch, in: project,
      settings: workspace.worktreeSettings(for: project))
  }

  func hasCommits(_ project: Project) async -> Bool {
    await worktrees?.hasCommits(project) ?? false
  }

  func branches(of project: Project) async -> (local: [String], remote: [String]) {
    (
      (try? await worktrees?.localBranches(project)) ?? [],
      (try? await worktrees?.remoteBranches(project)) ?? []
    )
  }

  func currentBranch(of project: Project) async -> String {
    (try? await worktrees?.currentBranch(project)) ?? "HEAD"
  }

  func createWorktree(
    branch: String,
    basedOn startPoint: String?,
    createBranch: Bool,
    in project: Project
  ) async {
    guard let worktrees else { return }
    let path: URL
    do {
      path = try await worktrees.create(
        branch: branch,
        basedOn: startPoint,
        createBranch: createBranch,
        in: project,
        settings: workspace.worktreeSettings(for: project),
        shellPath: workspace.defaultShell(for: project)
      )
    } catch let failure as HookFailure where failure.stage.operationHappened {
      // The worktree exists; only the hook went wrong. Refresh anyway so
      // it appears in the sidebar, then say what happened.
      report(failure)
      path = worktrees.plannedPath(
        forBranch: branch, createBranch: createBranch, in: project,
        settings: workspace.worktreeSettings(for: project))
    } catch {
      report(error)
      return
    }
    await refresh(project)
    await rearmWatcher()
    // git reports resolved paths, so on a symlinked volume the directory we
    // asked for and the one it lists can differ. Fall back to the branch.
    let name = WorktreeCoordinator.branchName(
      branch, createBranch: createBranch, settings: workspace.worktreeSettings(for: project))
    let created =
      workspace.worktree(path.standardizedFileURL.path)
      ?? workspace.worktrees(of: project.id).first { $0.branch == name }
    if let created {
      select(created)
    }
  }

  /// Entry point from the UI. Asks first unless the project opted out.
  func requestRemoval(of worktree: Worktree) {
    let confirms = workspace.project(worktree.projectID)?.settings.confirmsWorktreeRemoval ?? true
    if confirms {
      pendingRemoval = worktree
    } else {
      Task { await removeWorktree(worktree) }
    }
  }

  /// What the confirmation should warn about, beyond the removal itself.
  func removalWarning(for worktree: Worktree) -> String? {
    var notes: [String] = []
    if let status = statuses[worktree.id], status.isDirty {
      notes.append(
        "It has \(status.changedFiles) changed file\(status.changedFiles == 1 ? "" : "s") that will be lost."
      )
    }
    let terminals = liveTerminalCount(in: worktree.id)
    if terminals > 0 {
      notes.append("\(terminals) open terminal\(terminals == 1 ? "" : "s") will be closed.")
    }
    return notes.isEmpty ? nil : notes.joined(separator: " ")
  }

  func removeWorktree(_ worktree: Worktree, force: Bool = false) async {
    guard let worktrees, let project = workspace.project(worktree.projectID) else { return }
    do {
      try await worktrees.remove(
        worktree, force: force, in: project, shellPath: workspace.defaultShell(for: project))
    } catch let failure as HookFailure where failure.stage.operationHappened {
      report(failure)
    } catch let failure as HookFailure {
      // The pre-delete hook refused, so nothing was removed and there is
      // nothing to refresh.
      report(failure)
      return
    } catch {
      // git refuses dirty or locked worktrees. Offer the force form
      // rather than leaving the user to find a terminal.
      var presented = PresentedError(error)
      if !force {
        presented.retryLabel = "Remove Anyway"
        presented.retry = { [weak self] in await self?.removeWorktree(worktree, force: true) }
      }
      presentedError = presented
      return
    }
    await refresh(project)
    await rearmWatcher()
    sync()
  }
}
