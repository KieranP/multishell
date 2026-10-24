import Foundation
import MultishellCore
import MultishellGitKit

/// The git and disk reads behind the Files panel, each one at a time per
/// worktree or folder; see Docs/design/files.md.
extension AppModel {
  /// What a shown panel needs of its worktree: its tracked files, each folder open
  /// in it that git does not list, a status read and, under Branch, a branch read.
  public func readFilesPanel(of id: Worktree.ID) {
    forgetPanelListings { $0 != id }
    scheduleTrackedFilesRead(of: id)
    scheduleIgnoredEntriesRead(of: id)
    scheduleStatusRefresh(of: id)
    scheduleBranchChangesRead(of: id)
    for path in expandedSubmodules(of: id).keys { scheduleSubmoduleRead(path, in: id) }
    let expanded = filesPanelState(of: id).expandedFolders
    for path in (ignoredFolderEntries[id] ?? [:]).keys where expanded.contains(path) {
      scheduleIgnoredFolderRead(path, in: id)
    }
  }

  /// Linux's tracked files and their tree hold about 80 MB, so only the panel's
  /// own worktree keeps them; coming back reads them again.
  func forgetPanelListings(where isForgotten: (Worktree.ID) -> Bool) {
    for (id, task) in pendingTrackedFilesReads where isForgotten(id) {
      task.cancel()
      pendingTrackedFilesReads[id] = nil
    }
    ignoredEntriesReads.cancel(where: isForgotten)
    branchChangesReads.cancel(where: isForgotten)
    setIfChanged(\.branchChanges, branchChanges.filter { !isForgotten($0.key) })
    setIfChanged(\.failedBranchReads, failedBranchReads.filter { !isForgotten($0.key) })
    setIfChanged(\.trackedFiles, trackedFiles.filter { !isForgotten($0.key) })
    setIfChanged(\.ignoredEntries, ignoredEntries.filter { !isForgotten($0.key) })
    fileTreeCache = fileTreeCache.filter { !isForgotten($0.key) }
    for (id, task) in pendingFileTreeListings where isForgotten(id) {
      task.cancel()
      pendingFileTreeListings[id] = nil
    }
    fileTreeListings = fileTreeListings.filter { !isForgotten($0.key) }
    for (id, task) in pendingFileTreeChanges where isForgotten(id) {
      task.cancel()
      pendingFileTreeChanges[id] = nil
    }
    fileTreeChanges = fileTreeChanges.filter { !isForgotten($0.key) }
  }

  /// The tracked files change only with the index, so are read on git changes,
  /// never because a count moved; one at a time per worktree.
  func scheduleTrackedFilesRead(of id: Worktree.ID) {
    guard pendingTrackedFilesReads[id] == nil, let coordinator,
      let worktree = workspace.worktree(id)
    else { return }
    pendingTrackedFilesReads[id] = Task { @MainActor [weak self] in
      let tracked = await coordinator.git.trackedFiles(in: worktree.path)
      guard let self, !Task.isCancelled else { return }
      pendingTrackedFilesReads[id] = nil
      guard workspace.worktree(id) != nil, let tracked else { return }
      setIfChanged(\.trackedFiles[id], tracked)
    }
  }

  /// Paced, as an install or a build writes what git ignores constantly.
  func scheduleIgnoredEntriesRead(of id: Worktree.ID) {
    guard let coordinator, let worktree = workspace.worktree(id) else { return }
    let git = coordinator.git
    schedulePacedRead(
      id,
      in: id,
      on: \.ignoredEntriesReads,
      reading: { await git.ignoredEntries(in: worktree.path) },
      landing: { model, entries in
        guard let entries else { return }
        model.setIfChanged(\.ignoredEntries[id], entries)
        model.forgetFoldersNoLongerIgnored(in: id)
      },
      rerun: { $0.scheduleIgnoredEntriesRead(of: id) },
    )
  }

  /// A folder git stopped ignoring is listed by git again, its files no longer greyed.
  private func forgetFoldersNoLongerIgnored(in id: Worktree.ID) {
    guard let read = ignoredFolderEntries[id] else { return }
    let ignoredFolders = (ignoredEntries[id] ?? []).filter { $0.hasSuffix("/") }
    let kept = read.filter { path, _ in ignoredFolders.contains { (path + "/").hasPrefix($0) } }
    guard kept.count != read.count else { return }
    ignoredFolderEntries[id] = kept
    // A read already asked for would put the folder back, greyed again.
    let forgotten = Set(read.keys).subtracting(kept.keys)
    panelFolderReads.cancel { folderRead in
      folderRead.worktreeID == id && folderRead.kind == .ignoredFolder
        && forgotten.contains(folderRead.path)
    }
  }

  /// git lists nothing below a folder it ignores, so the disk is read, one
  /// level at a time, as each opens.
  func scheduleIgnoredFolderRead(_ path: String, in id: Worktree.ID) {
    guard let worktree = workspace.worktree(id) else { return }
    let folder = worktree.path.appending(path: path)
    schedulePacedRead(
      PanelFolderRead(kind: .ignoredFolder, path: path, worktreeID: id),
      in: id,
      on: \.panelFolderReads,
      reading: { await runOnDispatch { IgnoredFolderReader.entries(of: folder) } },
      landing: { model, entries in
        guard model.ignoredFolderEntries[id]?[path] != entries else { return }
        model.ignoredFolderEntries[id, default: [:]][path] = entries
      },
      rerun: { $0.scheduleIgnoredFolderRead(path, in: id) },
    )
  }

  /// `rev-parse --show-toplevel` must name the folder: in one nobody has
  /// initialised, `git -C` runs against the parent.
  func scheduleSubmoduleRead(_ path: String, in id: Worktree.ID) {
    guard let coordinator, let worktree = workspace.worktree(id) else { return }
    let git = coordinator.git
    let directory = worktree.path.appending(path: path)
    let indicator = workspace.gitStatusIndicator
    let algorithm = workspace.diffAlgorithm
    schedulePacedRead(
      PanelFolderRead(kind: .submodule, path: path, worktreeID: id),
      in: id,
      on: \.panelFolderReads,
      reading: {
        guard await git.isRepositoryTop(directory),
          let tracked = await git.trackedFiles(in: directory)
        else { return SubmoduleReading.uninitialised }
        let status = try? await git.status(
          inRepositoryAt: directory,
          counting: indicator,
          diffAlgorithm: algorithm,
        )
        return SubmoduleReading(tracked: tracked, status: status)
      },
      landing: { model, reading in
        guard model.submoduleReadings[id]?[path] != reading else { return }
        model.submoduleReadings[id, default: [:]][path] = reading
      },
      rerun: { $0.scheduleSubmoduleRead(path, in: id) },
    )
  }

  /// Events skipped while the window was covered: its file tabs and, in the
  /// background where no return to the front reads it, the panel.
  func readWhatTheWindowShowsOnceVisible() {
    readShownFileTabs()
    if showsFilesPanel, !platform.isActive, let worktree = filesPanelWorktree {
      readFilesPanel(of: worktree.id)
    }
  }

  /// The panel's worktree is read on its events while its window shows, front
  /// or not, so coming back never shows a stale list.
  func readsStatusInTheBackground(_ id: Worktree.ID) -> Bool {
    showsFilesPanel && platform.isWorkspaceWindowVisible && filesPanelWorktree?.id == id
  }
}
