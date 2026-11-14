import Foundation
import MultishellCore
import MultishellGitKit

/// Which All changes tabs a watcher batch, a status or Branch read, or a new
/// scope moved, and which of their files; see Docs/design/files/all-changes-tab.md.
extension AppModel {
  /// A git change in the project reads every file again, as each file tab
  /// would; an event in a listed file's folder reads the files whose `lstat` moved.
  func noteAllChangesTabChanges(_ targets: FileChangeTargets) {
    for tab in workspace.allChangesTabs {
      guard let worktree = workspace.worktree(tab.worktreeID) else { continue }
      let changed = targets.fileChangesByWorktree[worktree.id] ?? []
      if targets.projectsWithGitChanges.contains(worktree.projectID)
        || !(targets.embeddedRepositoriesWithGitChanges[worktree.id] ?? []).isEmpty
        || changed.contains(FileChangeTargets.wholeWorktree)
      {
        noteAllChangesTabChanged(tab.id, staleness: .everything)
      } else if let reading = allChangesReadings[tab.id], !changed.isEmpty {
        let touched = reading.files.filter { file in
          let folder = file.path.slashSeparatedParts.dropLast().joined(separator: "/")
          return changed.contains { $0 == folder || $0 == file.path }
        }
        if !touched.isEmpty { checkAllChangesSignatures(of: touched, in: tab, at: worktree.path) }
      }
      // Its window in the background, only the panel's worktree has its status read.
      if !changed.isEmpty || targets.projectsWithGitChanges.contains(worktree.projectID),
        !platform.isActive, isAllChangesTabShown(tab.id), targets.mayHaveChangedStatus(of: worktree)
      {
        scheduleStatusRefresh(of: worktree.id)
      }
    }
  }

  /// Off the main actor, a dead mount being able to hold an `lstat`.
  private func checkAllChangesSignatures(
    of files: [AllChangesFile],
    in tab: AllChangesTab,
    at worktree: URL,
  ) {
    let checked = files.map { ($0.path, $0.signature) }
    Task { @MainActor [weak self] in
      let moved = await runOnDispatch {
        checked.filter { path, signature in
          FileSignature.of(worktree.appending(path: path)) != signature
        }
        .map(\.0)
      }
      guard let self, !moved.isEmpty else { return }
      noteAllChangesTabChanged(tab.id, staleness: .paths(Set(moved)))
    }
  }

  /// A status or Branch read landing: files new to the list, or counted
  /// otherwise, are read again; the rest keep their rows.
  func noteAllChangesListLanded(in worktreeID: Worktree.ID) {
    guard let tab = workspace.allChangesTab(in: worktreeID),
      let list = allChangesList(of: worktreeID)
    else { return }
    guard let reading = allChangesReadings[tab.id] else {
      // A shown tab waiting on its first list reads now it has one.
      if isAllChangesTabShown(tab.id) { noteAllChangesTabChanged(tab.id, staleness: .nothing) }
      return
    }
    guard list != reading.listed else { return }
    let listed = Set(reading.listed)
    let moved = list.filter { !listed.contains($0) }.map(\.path)
    noteAllChangesTabChanged(tab.id, staleness: .paths(Set(moved)))
  }

  /// A new scope, algorithm or base: every file of the tabs it reaches is read
  /// afresh, at once rather than at the pace the old diffs set.
  func noteAllChangesTabsChanged(where isReached: (AllChangesTab) -> Bool) {
    for tab in workspace.allChangesTabs where isReached(tab) {
      allChangesReadLog.forgetPace(of: tab.id)
      pendingAllChangesReads.removeValue(forKey: tab.id)?.cancel()
      noteAllChangesTabChanged(tab.id, staleness: .everything)
    }
    readShownAllChangesTabs()
  }
}
