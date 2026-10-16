import Foundation
import MultishellCore
import MultishellGitKit

extension AppModel {
  /// A watcher tick, the round or a return to the front: the worktree list where git's
  /// records changed, else the shared settings file. `changed` empty is all.
  func refreshProjectsIfChanged(under changed: [URL] = []) async {
    let changedComponents = changed.map(\.standardizedFileURL.pathComponents)
    for project in workspace.projects {
      // A change names a watched folder, and only a known git directory is
      // watched; asking git here spawned it on every save for a broken project.
      let common =
        changed.isEmpty
        ? await commonGitDirectory(of: project) : commonGitDirectories[project.id]
      if !changed.isEmpty {
        guard let common else { continue }
        let gitDirectory = StandardizedPath(id: project.id, url: common)
        guard changedComponents.contains(where: { gitDirectory.subpath(to: $0) != nil })
        else { continue }
      }
      if let common, let known = worktreeRecords[project.id],
        await runOnDispatch({ WorktreeRecords.read(in: common) }) == known
      {
        await refreshSharedSettingsIfChanged(project)
        continue
      }
      await refreshWorktrees(of: project)
    }
  }

  /// Refresh chosen by the user. A failure already shown for this project is
  /// shown again: the click asked for an answer.
  public func refreshWorktreesOnRequest(of project: Project) async {
    missingProjects.remove(project.id)
    await refreshWorktrees(of: project)
    await rearmWatcher(evenIfUnchanged: true)
  }

  func refreshWorktrees(of project: Project) async {
    guard let coordinator else { return }
    let path = project.path
    guard await runOnDispatch({ FileManager.default.fileExists(atPath: path.path) }) else {
      if workspace.project(project.id) != nil { missingProjects.insert(project.id) }
      // Back again, its records would read as unchanged and leave it dimmed.
      worktreeRecords[project.id] = nil
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
      let wasMissing = missingProjects.remove(project.id) != nil
      applySharedSettingsReading(shared, for: project)
      // A worktree removed outside the app loses its tabs and sessions here,
      // and without this the host keeps their surfaces and the shells run on.
      reconcileSessions(takingFocus: false)
      // A folder that was away when last armed was skipped by the watcher.
      await rearmWatcher(evenIfUnchanged: wasMissing)
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
