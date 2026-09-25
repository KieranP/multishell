import Foundation
import MultishellCore
import MultishellGitKit

extension AppModel {
  func refreshAll() async {
    await refreshWorktreesIfRecordsChanged()
    await refreshStatuses()
    await refreshMergeStates()
  }

  /// A watcher tick or a return to the front. The records are compared before
  /// git is spawned; `changed` narrows it to the projects that fired, empty is all.
  func refreshWorktreesIfRecordsChanged(under changed: [URL] = []) async {
    var refreshed = false
    for project in workspace.projects {
      let common = await commonGitDirectory(of: project)
      if !changed.isEmpty {
        guard let common, changed.contains(where: { $0.pathComponents(under: common) != nil })
        else { continue }
      }
      if let common, let known = worktreeRecords[project.id],
        await offMain({ WorktreeRecords.read(commonDirectory: common) }) == known
      {
        await refreshSharedSettingsIfChanged(project)
        continue
      }
      await refresh(project)
      refreshed = true
    }
    if refreshed { await rearmWatcher() }
  }

  /// Refresh chosen by the user. A failure already shown for this project is
  /// shown again: the click asked for an answer.
  public func refreshOnRequest(_ project: Project) async {
    missingProjects.remove(project.id)
    await refresh(project)
  }

  func refresh(_ project: Project) async {
    guard let coordinator else { return }
    let path = project.path
    guard await offMain({ FileManager.default.fileExists(atPath: path.path) }) else {
      if workspace.project(project.id) != nil { missingProjects.insert(project.id) }
      return
    }
    // Read before the list so a change landing in between is caught by the
    // next tick rather than lost.
    var records: WorktreeRecords?
    if let common = await commonGitDirectory(of: project) {
      records = await offMain { WorktreeRecords.read(commonDirectory: common) }
    }
    let shared = await offMain { Self.readSharedSettings(of: project) }
    do {
      let discovered = try await coordinator.git.list(project)
      guard isStillListedElseForgetCache(project.id) else { return }
      forgetWorktrees(store.replaceWorktrees(discovered, forProject: project.id))
      worktreeRecords[project.id] = records
      missingProjects.remove(project.id)
      applySharedSettingsReading(shared, for: project)
      // A worktree removed outside the app loses its tabs and sessions here,
      // and without this the host keeps their surfaces and the shells run on.
      reconcileSessions(takingFocus: false)
    } catch {
      // Nothing to dim for a project removed meanwhile.
      guard isStillListedElseForgetCache(project.id) else { return }
      // Every tick and every return to the front refreshes a project git
      // cannot read, so the alert goes up once; the row stays dimmed.
      if missingProjects.insert(project.id).inserted { present(error) }
    }
  }

  /// A project removed while git ran: the store ignores its list, and the
  /// records and directory cached for it must not come back either.
  private func isStillListedElseForgetCache(_ id: Project.ID) -> Bool {
    guard workspace.project(id) == nil else { return true }
    commonGitDirectories[id] = nil
    return false
  }

  /// Re-read after every refresh: a new worktree adds a directory that must
  /// itself be watched for branch changes.
  func rearmWatcher() async {
    var directories: [URL] = []
    for project in workspace.projects {
      guard let common = await commonGitDirectory(of: project) else { continue }
      directories += await offMain { WorktreeRecords.directoriesToWatch(in: common) }
    }
    await watcher.watch(directories)
  }

  func commonGitDirectory(of project: Project) async -> URL? {
    if let cached = commonGitDirectories[project.id] { return cached }
    guard let coordinator, let common = try? await coordinator.git.commonGitDirectory(project)
    else {
      return nil
    }
    commonGitDirectories[project.id] = common
    return common
  }

  /// Whether a fetch is running on this project: its row spins, and the
  /// menu item that started it is disabled until it ends.
  public func isFetching(_ project: Project) -> Bool {
    fetchingProjects.contains(project.id)
  }

  /// The menus' Fetch, the one git call that talks to a network and only on
  /// a click. Marked for the whole of it, re-reads included.
  public func fetch(_ project: Project) async {
    guard let coordinator, fetchingProjects.insert(project.id).inserted else { return }
    defer { fetchingProjects.remove(project.id) }
    do {
      try await coordinator.git.fetch(project)
    } catch {
      present(error)
      return
    }
    await refresh(project)
    await refreshStatuses()
    await refreshMergeStates(of: project)
  }
}
