import Foundation
import MultishellCore
import MultishellGitKit

/// Keeping each All changes tab's files current with the worktree's changes,
/// paced and released as a file tab's are; see Docs/design/files/all-changes-tab.md.
extension AppModel {
  /// The worktree's All changes tab where it is shown.
  func shownAllChangesTab(in worktreeID: Worktree.ID) -> AllChangesTab? {
    workspace.allChangesTab(in: worktreeID).flatMap { isTabShown($0.id) ? $0 : nil }
  }

  /// What the Changes list lists under the scope, in its order; `nil` while
  /// the read it comes from has yet to land.
  func allChangesList(of id: Worktree.ID) -> [AllChangesFileChange]? {
    guard let changes = allChangesListedChanges(of: id) else { return nil }
    if let cached = allChangesLists[id], cached.changes == changes { return cached.list }
    let list = AllChangesOrder.files(of: changes)
    allChangesLists[id] = AllChangesListCacheEntry(changes: changes, list: list)
    return list
  }

  /// The same changes as git listed them, unsorted, for a check of whether a
  /// list has landed or holds a path: sorting thousands costs a status landing.
  func allChangesListedChanges(of id: Worktree.ID) -> [StatusChange]? {
    if let base = fileTabBase(in: id) {
      guard let changes = branchChanges[id], changes.baseName == base.shortName else { return nil }
      return changes.changes
    }
    return statuses[id]?.changes
  }

  /// A shown tab reads once the burst settles; a hidden one is owed a read.
  func noteAllChangesTabChanged(_ id: AllChangesTab.ID, staleness: AllChangesStaleness) {
    guard workspace.allChangesTab(id) != nil else { return }
    allChangesStaleFiles.mark(staleness, in: id)
    if isTabShown(id), platform.isWorkspaceWindowVisible {
      scheduleAllChangesRead(id)
    } else {
      allChangesReadLog.owe(id)
    }
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

  /// The tabs on screen holding nothing, or owed a read while hidden, and the
  /// Branch read their list waits on.
  func readShownAllChangesTabs() {
    guard platform.isWorkspaceWindowVisible, let worktree = worktreeIDInView,
      let tab = shownAllChangesTab(in: worktree)
    else { return }
    scheduleBranchChangesRead(of: worktree)
    let isWaitedFor = allChangesReadings[tab.id] == nil
    guard isWaitedFor || allChangesReadLog.owed.contains(tab.id) else { return }
    guard !allChangesReadLog.isReading(tab.id) else {
      if allChangesReadLog.owed.contains(tab.id) { allChangesReadLog.askAgain(tab.id) }
      return
    }
    scheduleAllChangesRead(tab.id, atOnce: isWaitedFor)
  }

  /// A shown tab that has read nothing, its list just landed: read at once,
  /// without the settle and pace a change waits for.
  func readAllChangesTabWaitingForItsList(_ id: AllChangesTab.ID) {
    guard platform.isWorkspaceWindowVisible else {
      allChangesReadLog.owe(id)
      return
    }
    scheduleAllChangesRead(id, atOnce: true)
  }

  /// The view's, as it builds files: those near its screen, which a read reads;
  /// one there unread or stale is read at once.
  public func noteAllChangesFilesNear(_ paths: Set<String>, in id: AllChangesTab.ID) {
    guard allChangesFilesNear[id] != paths else { return }
    allChangesFilesNear[id] = paths
    readNearFilesOwed(in: id)
  }

  /// The files near the screen a read reads, a collapsed one showing no rows, and
  /// the composer's wherever it is: its quote is checked against them on Add.
  private func nearFilesToRead(in id: AllChangesTab.ID) -> Set<String> {
    var near = (allChangesFilesNear[id] ?? []).subtracting(allChangesCollapsedFiles[id] ?? [])
    if let composer = reviewComposers[id] { near.insert(composer.path) }
    return near
  }

  /// Read at once where a file near the screen is owed one, as scrolled to,
  /// expanded or left stale; a covered window owes the read instead.
  func readNearFilesOwed(in id: AllChangesTab.ID) {
    guard let reading = allChangesReadings[id], isTabShown(id),
      nearFilesToRead(in: id).contains(where: reading.owesRead)
    else { return }
    guard platform.isWorkspaceWindowVisible else {
      allChangesReadLog.owe(id)
      return
    }
    scheduleAllChangesRead(id, atOnce: true)
  }

  /// A hidden tab holds no rows, so content nobody sees holds no memory; its
  /// waiting read is owed instead.
  func releaseHiddenAllChangesTabs() {
    for tab in workspace.allChangesTabs where !isTabShown(tab.id) {
      forgetChangeSteps(of: tab.id)
      if let task = pendingAllChangesReads.removeValue(forKey: tab.id) {
        task.cancel()
        allChangesReadLog.owe(tab.id)
      }
      guard allChangesReadings[tab.id] != nil, !allChangesReadLog.isReading(tab.id) else {
        continue
      }
      allChangesReadings[tab.id] = nil
      allChangesDocuments[tab.id] = nil
    }
  }

  /// One read per tab at a time, after the settle and once its pace allows, or
  /// `atOnce` in place of one waiting; a change during a read is read again after it.
  private func scheduleAllChangesRead(_ id: AllChangesTab.ID, atOnce: Bool = false) {
    if atOnce { pendingAllChangesReads.removeValue(forKey: id)?.cancel() }
    guard pendingAllChangesReads[id] == nil else { return }
    pendingAllChangesReads[id] = pacedTabRead(atOnce: atOnce) { model in
      model.allChangesReadLog.nextDue(id, costScale: model.filesOwed(by: id))
    } read: { model in
      model.pendingAllChangesReads[id] = nil
      await model.readAllChangesTab(id)
    }
  }

  func readAllChangesTab(_ id: AllChangesTab.ID) async {
    guard let coordinator, let tab = workspace.allChangesTab(id),
      let worktree = workspace.worktree(tab.worktreeID)
    else { return }
    // A Branch list still to land reads the tab when it does.
    guard let list = allChangesList(of: tab.worktreeID) else { return }
    guard !allChangesReadLog.isReading(id) else {
      allChangesReadLog.askAgain(id)
      return
    }
    allChangesReadLog.begin(id)
    let started = ContinuousClock.now
    let rereading = allChangesStaleFiles.take(id)
    let (reading, filesRead) = await AllChangesReader.read(
      list,
      in: worktree.path,
      git: coordinator.git,
      diffAlgorithm: workspace.diffAlgorithm,
      since: fileTabBase(in: tab.worktreeID),
      previous: allChangesReadings[id],
      rereading: rereading,
      imageRule: imageRule,
      near: nearFilesToRead(in: id),
    )
    let isSuperseded = allChangesReadLog.isSuperseded(id)
    // Noted a file's worth, the next read waiting by the files it will read.
    let readsAgain = allChangesReadLog.finish(
      id,
      cost: started.duration(to: .now) / max(1, filesRead),
    )
    guard workspace.allChangesTab(id) != nil else { return }
    guard !isSuperseded else {
      if isTabShown(id) { scheduleAllChangesRead(id) } else { allChangesReadLog.owe(id) }
      return
    }
    // Hidden while it ran, it would hold rows nobody sees; shown again it reads anew.
    guard isTabShown(id) else {
      allChangesStaleFiles.mark(rereading, in: id)
      allChangesReadLog.owe(id)
      releaseHiddenAllChangesTabs()
      return
    }
    let previous = allChangesReadings[id]
    let before = allChangesDocument(of: id).map(SearchedLayout.allChanges)
    if setIfChanged(\.allChangesReadings[id], reading) {
      reanchorReview(in: tab, toFilesMovedSince: previous, in: reading)
      rerunFileFind(in: id, laidOutBefore: before)
    }
    // Files scrolled to while it ran were read by none; the near set did not change since.
    readNearFilesOwed(in: id)
    if readsAgain { scheduleAllChangesRead(id) }
  }

  /// Each file whose rows moved has its comments, and the composer on it,
  /// follow their quotes, as a file tab's read does; a gone or stale file's stay put.
  private func reanchorReview(
    in tab: AllChangesTab,
    toFilesMovedSince previous: AllChangesReading?,
    in reading: AllChangesReading,
  ) {
    let scope = fileTabScope(in: tab.worktreeID)
    var rowsByPath: [String: [DiffLine]] = [:]
    for file in reading.files where !file.isStale && file != previous?.file(at: file.path) {
      guard let rows = file.rows, file.reading?.isFileGone == false else { continue }
      rowsByPath[file.path] = rows.lines
      reanchorReviewComposer(in: tab.id, onFile: file.path, to: rows.lines, readUnder: scope)
    }
    reanchorReviewComments(onFiles: rowsByPath, in: tab.worktreeID, readUnder: scope)
  }

  /// How many files the next read reads: those near the screen that a git
  /// change, an event or the list moved, the rest only kept stale.
  func filesOwed(by id: AllChangesTab.ID) -> Int {
    let near = nearFilesToRead(in: id)
    switch allChangesStaleFiles.pending(id) {
    case .everything: return max(1, near.count)
    case .paths(let paths): return max(1, paths.intersection(near).count)
    }
  }

  /// A closed tab's rows, reads and pending work go with it. Run from the reconcile.
  func pruneAllChangesTabs() {
    let open = Set(workspace.allChangesTabs.map(\.id))
    setIfChanged(\.allChangesReadings, allChangesReadings.filter { open.contains($0.key) })
    for (id, task) in pendingAllChangesReads where !open.contains(id) {
      task.cancel()
      pendingAllChangesReads[id] = nil
    }
    allChangesReadLog.keep(only: open)
    allChangesStaleFiles.keep(only: open)
    allChangesFilesNear = allChangesFilesNear.filter { open.contains($0.key) }
    let listed = Set(workspace.allChangesTabs.map(\.worktreeID))
    allChangesLists = allChangesLists.filter { listed.contains($0.key) }
    allChangesScrolls = allChangesScrolls.filter { open.contains($0.key) }
    setIfChanged(
      \.allChangesCollapsedFiles,
      allChangesCollapsedFiles.filter { open.contains($0.key) },
    )
    setIfChanged(\.allChangesOpenedFolds, allChangesOpenedFolds.filter { open.contains($0.key) })
    setIfChanged(\.allChangesTopFiles, allChangesTopFiles.filter { open.contains($0.key) })
    setIfChanged(\.allChangesLitPaths, allChangesLitPaths.filter { open.contains($0.key) })
    setIfChanged(\.allChangesFileReveals, allChangesFileReveals.filter { open.contains($0.key) })
    allChangesDocuments = allChangesDocuments.filter { open.contains($0.key) }
  }
}
