import Foundation
import MultishellCore
import MultishellGitKit

extension AppModel {
  /// A watcher tick or a return to the front: the worktree list where git's
  /// records changed, else the shared settings file. `changed` empty is all.
  func refreshProjectsIfChanged(under changed: [URL] = []) async {
    var refreshed = false
    for project in workspace.projects {
      let common = await commonGitDirectory(of: project)
      if !changed.isEmpty {
        guard let common, changed.contains(where: { $0.pathComponents(under: common) != nil })
        else { continue }
      }
      if let common, let known = worktreeRecords[project.id],
        await runOnDispatch({ WorktreeRecords.read(in: common) }) == known
      {
        await refreshSharedSettingsIfChanged(project)
        continue
      }
      await refreshWorktrees(of: project)
      refreshed = true
    }
    if refreshed { await rearmWatcher() }
  }

  /// Refresh chosen by the user. A failure already shown for this project is
  /// shown again: the click asked for an answer.
  public func refreshWorktreesOnRequest(of project: Project) async {
    missingProjects.remove(project.id)
    await refreshWorktrees(of: project)
  }

  func refreshWorktrees(of project: Project) async {
    guard let coordinator else { return }
    let path = project.path
    guard await runOnDispatch({ FileManager.default.fileExists(atPath: path.path) }) else {
      if workspace.project(project.id) != nil { missingProjects.insert(project.id) }
      return
    }
    // Read before the list so a change landing in between is caught by the
    // next tick rather than lost.
    var records: WorktreeRecords?
    if let common = await commonGitDirectory(of: project) {
      records = await runOnDispatch { WorktreeRecords.read(in: common) }
    }
    let shared = await runOnDispatch { SharedSettingsReading.read(from: project) }
    do {
      let discovered = try await coordinator.git.list(project)
      guard forgetCacheUnlessListed(project.id) else { return }
      forgetWorktrees(store.replaceWorktrees(discovered, forProject: project.id))
      worktreeRecords[project.id] = records
      missingProjects.remove(project.id)
      applySharedSettingsReading(shared, for: project)
      // A worktree removed outside the app loses its tabs and sessions here,
      // and without this the host keeps their surfaces and the shells run on.
      reconcileSessions(takingFocus: false)
    } catch {
      // Nothing to dim for a project removed meanwhile.
      guard forgetCacheUnlessListed(project.id) else { return }
      // Every tick and every return to the front refreshes a project git
      // cannot read, so the alert goes up once; the row stays dimmed.
      if missingProjects.insert(project.id).inserted { present(error) }
    }
  }

  /// Whether the project is still listed. One removed while git ran has its list
  /// ignored by the store, and its cached directory dropped here as well.
  private func forgetCacheUnlessListed(_ id: Project.ID) -> Bool {
    guard workspace.project(id) == nil else { return true }
    commonGitDirectories[id] = nil
    return false
  }

  func refreshWorktrees(ofProjects ids: some Sequence<Project.ID>) async {
    for id in ids {
      if let project = workspace.project(id) { await refreshWorktrees(of: project) }
    }
  }
}
