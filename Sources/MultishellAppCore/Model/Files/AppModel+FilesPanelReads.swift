import Foundation
import MultishellCore
import MultishellGitKit

/// The git and disk reads behind the Files panel, each one at a time per
/// worktree; see Docs/design/files.md.
extension AppModel {
  /// Ten times what the last read and rebuild cost, so a build's churn takes
  /// about a tenth of a core.
  private static var ignoredReadCostMultiple: Int { 10 }

  /// What a shown panel needs of its worktree: its tracked files, each folder open
  /// in it that git does not list, and a status read.
  public func readFilesPanel(of id: Worktree.ID) {
    forgetPanelListings(except: id)
    scheduleTrackedFilesRead(of: id)
    scheduleIgnoredEntriesRead(of: id)
    scheduleStatusRefresh(of: id)
    let expanded = filesPanelState(of: id).expandedFolders
    for path in (submoduleReadings[id] ?? [:]).keys where expanded.contains(path) {
      scheduleSubmoduleRead(path, in: id)
    }
    for path in (ignoredFolderEntries[id] ?? [:]).keys where expanded.contains(path) {
      scheduleIgnoredFolderRead(path, in: id)
    }
  }

  /// Linux's tracked files and their tree hold about 80 MB, so only the panel's
  /// own worktree keeps them; coming back reads them again.
  func forgetPanelListings(except kept: Worktree.ID?) {
    let isKept = { (id: Worktree.ID) in id == kept }
    for (id, task) in pendingTrackedFilesReads where !isKept(id) {
      task.cancel()
      pendingTrackedFilesReads[id] = nil
    }
    for (id, task) in pendingIgnoredEntriesReads where !isKept(id) {
      task.cancel()
      pendingIgnoredEntriesReads[id] = nil
    }
    setIfChanged(\.trackedFiles, trackedFiles.filter { isKept($0.key) })
    setIfChanged(\.ignoredEntries, ignoredEntries.filter { isKept($0.key) })
    fileTreeCache = fileTreeCache.filter { isKept($0.key) }
    for (id, pending) in pendingFileTreeListings where !isKept(id) {
      pending.task.cancel()
      pendingFileTreeListings[id] = nil
    }
    fileTreeListings = fileTreeListings.filter { isKept($0.key) }
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

  /// An install or a build writes what git ignores constantly, so one read runs
  /// at a time, the next waiting on its cost and the listing rebuild it set off.
  func scheduleIgnoredEntriesRead(of id: Worktree.ID) {
    guard pendingIgnoredEntriesReads[id] == nil else {
      ignoredEntriesAskedAgain.insert(id)
      return
    }
    guard let coordinator, let worktree = workspace.worktree(id) else { return }
    pendingIgnoredEntriesReads[id] = Task { @MainActor [weak self] in
      let started = ContinuousClock.now
      let entries = await coordinator.git.ignoredEntries(in: worktree.path)
      let cost = started.duration(to: .now)
      if let entries, let self, !Task.isCancelled, workspace.worktree(id) != nil {
        setIfChanged(\.ignoredEntries[id], entries)
        forgetFoldersNoLongerIgnored(in: id)
      }
      let rebuildCost = self?.fileTreeListings[id]?.buildCost ?? .zero
      try? await Task.sleep(
        for: max(.seconds(1), (cost + rebuildCost) * Self.ignoredReadCostMultiple)
      )
      guard let self, !Task.isCancelled else { return }
      pendingIgnoredEntriesReads[id] = nil
      if ignoredEntriesAskedAgain.remove(id) != nil { scheduleIgnoredEntriesRead(of: id) }
    }
  }

  /// A folder git stopped ignoring is listed by git again, its files no longer greyed.
  private func forgetFoldersNoLongerIgnored(in id: Worktree.ID) {
    guard let read = ignoredFolderEntries[id] else { return }
    let ignoredFolders = (ignoredEntries[id] ?? []).filter { $0.hasSuffix("/") }
    let kept = read.filter { path, _ in ignoredFolders.contains { (path + "/").hasPrefix($0) } }
    if kept.count != read.count { ignoredFolderEntries[id] = kept }
  }

  /// git lists nothing below a folder it ignores, so the disk is read, one
  /// level at a time, as each opens.
  func scheduleIgnoredFolderRead(_ path: String, in id: Worktree.ID) {
    guard let worktree = workspace.worktree(id) else { return }
    let folder = worktree.path.appending(path: path)
    Task { @MainActor [weak self] in
      let entries = await runOnDispatch { IgnoredFolderReader.entries(of: folder) }
      guard let self, workspace.worktree(id) != nil,
        ignoredFolderEntries[id]?[path] != entries
      else { return }
      ignoredFolderEntries[id, default: [:]][path] = entries
    }
  }

  /// `rev-parse --show-toplevel` must name the folder: in one nobody has
  /// initialised, `git -C` runs against the parent.
  func scheduleSubmoduleRead(_ path: String, in id: Worktree.ID) {
    guard let coordinator, let worktree = workspace.worktree(id) else { return }
    let directory = worktree.path.appending(path: path)
    let indicator = workspace.gitStatusIndicator
    let algorithm = workspace.diffAlgorithm
    Task { @MainActor [weak self] in
      let git = coordinator.git
      let reading: SubmoduleReading
      if await git.isRepositoryTop(directory), let tracked = await git.trackedFiles(in: directory) {
        let status = try? await git.status(
          inRepositoryAt: directory,
          counting: indicator,
          diffAlgorithm: algorithm,
        )
        reading = SubmoduleReading(tracked: tracked, status: status)
      } else {
        reading = .uninitialised
      }
      guard let self, workspace.worktree(id) != nil else { return }
      guard submoduleReadings[id]?[path] != reading else { return }
      submoduleReadings[id, default: [:]][path] = reading
    }
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
