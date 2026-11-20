import Foundation
import MultishellCore
import MultishellGitKit

/// Which All changes tabs a watcher batch or a status or Branch read moved, and
/// which of their files; see Docs/design/files/all-changes-tab.md.
extension AppModel {
  /// What moved each tab's files, as each file tab would read it; see "A read
  /// reads only what moved" in Docs/design/files/all-changes-tab.md.
  func noteAllChangesTabChanges(_ targets: FileChangeTargets) {
    for tab in workspace.allChangesTabs {
      guard let worktree = workspace.worktree(tab.worktreeID) else { continue }
      let changed = targets.fileChangesByWorktree[worktree.id] ?? []
      let embedded = targets.embeddedRepositoriesWithGitChanges[worktree.id] ?? []
      let reading = allChangesReadings[tab.id]
      if targets.projectsWithGitChanges.contains(worktree.projectID)
        || changed.contains(FileChangeTargets.wholeWorktree)
        || (!embedded.isEmpty && reading == nil)
      {
        noteAllChangesTabChanged(tab.id, staleness: .everything)
      } else if let reading {
        let inRepositories = reading.paths(inRepositories: embedded)
        if !inRepositories.isEmpty {
          noteAllChangesTabChanged(tab.id, staleness: .paths(inRepositories))
        }
        let touched = changed.isEmpty ? [] : reading.filesTouched(by: changed)
        if !touched.isEmpty { checkAllChangesSignatures(of: touched, in: tab, at: worktree.path) }
      }
      if !changed.isEmpty, allChangesReadLog.isReading(tab.id) {
        noteChangesDuringRead(changed, in: tab)
      }
      // Its window in the background, only the panel's worktree has its status read.
      if !platform.isActive, isTabShown(tab.id), targets.mayHaveChangedStatus(of: worktree) {
        scheduleStatusRefresh(of: worktree.id)
      }
    }
  }

  /// A read under way may have read a file before this change, which the
  /// reading it replaces held unread or stale and so would not check.
  private func noteChangesDuringRead(_ changed: [String], in tab: AllChangesTab) {
    guard let list = allChangesList(of: tab.worktreeID) else { return }
    let isTouched = AllChangesReading.isTouched(by: changed)
    let touched = Set(list.map(\.path).filter(isTouched))
    if !touched.isEmpty { noteAllChangesTabChanged(tab.id, staleness: .paths(touched)) }
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
    guard let tab = workspace.allChangesTab(in: worktreeID) else { return }
    guard let reading = allChangesReadings[tab.id] else {
      // A shown tab waiting on its first list reads now it has one, unpaced: it shows nothing.
      if isTabShown(tab.id), allChangesListedChanges(of: worktreeID) != nil {
        readAllChangesTabWaitingForItsList(tab.id)
      }
      return
    }
    guard let list = allChangesList(of: worktreeID) else { return }
    // Unchanged, a read that waited on this list still has what it was to read.
    guard list != reading.listed || allChangesStaleFiles.pending(tab.id) != .nothing else { return }
    let listed = Set(reading.listed)
    let moved = list.filter { !listed.contains($0) }.map(\.path)
    noteAllChangesTabChanged(tab.id, staleness: .paths(Set(moved)))
  }
}
