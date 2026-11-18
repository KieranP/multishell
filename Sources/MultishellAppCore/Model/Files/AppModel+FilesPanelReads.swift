import Foundation
import MultishellCore
import MultishellGitKit

/// The git and disk reads behind the Files panel, each one at a time per
/// worktree or folder; see Docs/design/files/panel.md.
extension AppModel {
  /// What a shown panel needs of its worktree: its tracked files, each folder open
  /// in it that git does not list, a status read and, under Branch, a branch read.
  public func readFilesPanel(of id: Worktree.ID) {
    remoteState.lastReadFilesPanelMode = shownFilesPanelMode
    forgetUnreadFileListings()
    guard shownFilesPanelMode.listsFiles else {
      if shownFilesPanelMode.isServicePage { schedulePanelServicesRead(of: id) }
      return
    }
    scheduleTrackedFilesRead(of: id)
    scheduleStatusRefresh(of: id)
    scheduleBranchChangesRead(of: id)
    for path in expandedSubmodules(of: id).keys { scheduleSubmoduleRead(path, in: id) }
    scheduleIgnoredReads(of: id)
  }

  /// What git ignores in the worktree, and each ignored folder open in its panel.
  func scheduleIgnoredReads(of id: Worktree.ID) {
    scheduleIgnoredEntriesRead(of: id)
    let expanded = filesPanelState(of: id).expandedFolders
    for path in (ignoredFolderEntries[id] ?? [:]).keys where expanded.contains(path) {
      scheduleIgnoredFolderRead(path, in: id)
    }
  }

  /// Keeps only the listings something still reads: a shown file page's worktree's,
  /// and the selected worktree's while the quick switcher is up.
  func forgetUnreadFileListings() {
    var read = Set<Worktree.ID>()
    if isFileListOnScreen, let id = filesPanelWorktree?.id { read.insert(id) }
    if quickSwitcher != nil, let id = workspace.selectedWorktreeID { read.insert(id) }
    forgetFileListings { !read.contains($0) }
  }

  /// Linux's tracked files and their tree hold about 80 MB, so only the listings
  /// `forgetUnreadFileListings` names are kept; coming back reads them again.
  func forgetFileListings(where isForgotten: (Worktree.ID) -> Bool) {
    for (id, task) in pendingTrackedFilesReads where isForgotten(id) {
      task.cancel()
      pendingTrackedFilesReads[id] = nil
    }
    trackedFilesReadsAskedAgain = trackedFilesReadsAskedAgain.filter { !isForgotten($0) }
    ignoredEntriesReads.cancel(where: isForgotten)
    // A shown All changes tab takes its list from the Branch read, panel or not.
    func forgetsBranch(_ id: Worktree.ID) -> Bool { isForgotten(id) && !readsBranchChanges(of: id) }
    branchChangesReads.cancel(where: forgetsBranch)
    setIfChanged(\.branchChanges, branchChanges.filter { !forgetsBranch($0.key) })
    setIfChanged(\.failedBranchReads, failedBranchReads.filter { !forgetsBranch($0.key) })
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

  /// Read on git changes, never because a count moved; one at a time per worktree,
  /// one asked for meanwhile running after it, the index maybe past what it read.
  /// With `withIgnoredEntries`, what git ignores lands with it, so one listing is built.
  func scheduleTrackedFilesRead(of id: Worktree.ID, withIgnoredEntries readsIgnored: Bool = false) {
    guard pendingTrackedFilesReads[id] == nil else {
      trackedFilesReadsAskedAgain.insert(id)
      return
    }
    guard let coordinator, let worktree = workspace.worktree(id) else { return }
    let git = coordinator.git
    pendingTrackedFilesReads[id] = Task { @MainActor [weak self] in
      async let ignored = readsIgnored ? await git.ignoredEntries(in: worktree.path) : nil
      let tracked = await git.trackedFiles(in: worktree.path)
      let ignoredEntries = await ignored
      guard let self, !Task.isCancelled else { return }
      pendingTrackedFilesReads[id] = nil
      if trackedFilesReadsAskedAgain.remove(id) != nil { scheduleTrackedFilesRead(of: id) }
      guard workspace.worktree(id) != nil, let tracked else {
        // Nothing observed moved, and what waited on the read must still redraw.
        fileTreeBuildLandings += 1
        return
      }
      if let ignoredEntries { landIgnoredEntries(ignoredEntries, in: id) }
      setIfChanged(\.trackedFiles[id], tracked)
    }
  }

  /// Paced, as an install or a build writes what git ignores constantly.
  func scheduleIgnoredEntriesRead(of id: Worktree.ID) {
    guard showsIgnoredFiles, let coordinator, let worktree = workspace.worktree(id) else { return }
    let git = coordinator.git
    schedulePacedRead(
      id,
      in: id,
      on: \.ignoredEntriesReads,
      reading: { await git.ignoredEntries(in: worktree.path) },
      landing: { model, entries in
        guard let entries else { return }
        model.landIgnoredEntries(entries, in: id)
      },
      rerun: { $0.scheduleIgnoredEntriesRead(of: id) },
    )
  }

  private func landIgnoredEntries(_ entries: [String], in id: Worktree.ID) {
    setIfChanged(\.ignoredEntries[id], entries)
    forgetFoldersNoLongerIgnored(in: id)
  }

  /// A folder git stopped ignoring is listed by git again, its files no longer greyed.
  private func forgetFoldersNoLongerIgnored(in id: Worktree.ID) {
    guard let read = ignoredFolderEntries[id] else { return }
    let ignoredFolders = (ignoredEntries[id] ?? []).filter { $0.hasSuffix("/") }
      .map { String($0.dropLast()) }
    let kept = read.filter { path, _ in
      ignoredFolders.contains { path == $0 || path.isPath(under: $0) }
    }
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
    guard showsIgnoredFiles, let worktree = workspace.worktree(id) else { return }
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
      reading: { () -> SubmoduleReading? in
        guard await git.isRepositoryTop(directory) else { return SubmoduleReading.uninitialised }
        // A list or status git could not read is no answer, and keeps the last reading.
        guard let tracked = await git.trackedFiles(in: directory),
          let status = try? await git.status(
            inRepositoryAt: directory,
            counting: indicator,
            diffAlgorithm: algorithm,
          )
        else { return nil }
        return SubmoduleReading(tracked: tracked, status: status)
      },
      landing: { model, reading in
        guard let reading, model.submoduleReadings[id]?[path] != reading else { return }
        model.submoduleReadings[id, default: [:]][path] = reading
      },
      rerun: { $0.scheduleSubmoduleRead(path, in: id) },
    )
  }

  /// Events skipped while the window was covered: its file and All changes
  /// tabs and, in the background where no return to the front reads it, the panel.
  func readWhatTheWindowShowsOnceVisible() {
    readShownFileTabs()
    readShownAllChangesTabs()
    if showsFilesPanel, !platform.isActive, let worktree = filesPanelWorktree {
      readFilesPanel(of: worktree.id)
    }
  }

  /// The panel's worktree, and a shown All changes tab's, is read on its events
  /// while its window shows, front or not, so coming back never shows a stale list.
  func readsStatusInTheBackground(_ id: Worktree.ID) -> Bool {
    guard platform.isWorkspaceWindowVisible else { return false }
    return (isFileListOnScreen && filesPanelWorktree?.id == id) || shownAllChangesTab(in: id) != nil
  }
}
