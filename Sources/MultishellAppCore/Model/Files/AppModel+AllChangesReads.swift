import Foundation
import MultishellCore
import MultishellGitKit

/// Keeping each All changes tab's files current with the worktree's changes,
/// paced and released as a file tab's are; see Docs/design/files/all-changes-tab.md.
extension AppModel {
  /// A burst of saves becomes one read, as a file tab's does.
  private static var allChangesSettleDelay: Duration { .milliseconds(75) }

  /// In front of its group, in the worktree in view.
  func isAllChangesTabShown(_ id: AllChangesTab.ID) -> Bool {
    guard let tab = workspace.allChangesTab(id), tab.worktreeID == worktreeIDInView else {
      return false
    }
    return workspace.group(tab.groupID)?.shownTabID == id
  }

  /// The worktree's All changes tab where it is shown.
  func shownAllChangesTab(in worktreeID: Worktree.ID) -> AllChangesTab? {
    workspace.allChangesTab(in: worktreeID).flatMap { isAllChangesTabShown($0.id) ? $0 : nil }
  }

  /// What the Changes list lists under the scope, in its order; `nil` while
  /// the read it comes from has yet to land.
  func allChangesList(of id: Worktree.ID) -> [AllChangesFileChange]? {
    if let base = fileTabBase(in: id) {
      guard let changes = branchChanges[id], changes.baseName == base.shortName else { return nil }
      return AllChangesOrder.files(of: changes.changes)
    }
    return statuses[id].map { AllChangesOrder.files(of: $0.changes) }
  }

  /// A shown tab reads once the burst settles; a hidden one is owed a read.
  func noteAllChangesTabChanged(_ id: AllChangesTab.ID, staleness: AllChangesStaleness) {
    guard workspace.allChangesTab(id) != nil else { return }
    allChangesStaleFiles.mark(staleness, in: id)
    if isAllChangesTabShown(id), platform.isWorkspaceWindowVisible {
      scheduleAllChangesRead(id)
    } else {
      allChangesReadLog.owe(id)
    }
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

  /// A hidden tab holds no rows, so content nobody sees holds no memory; its
  /// waiting read is owed instead.
  func releaseHiddenAllChangesTabs() {
    for tab in workspace.allChangesTabs where !isAllChangesTabShown(tab.id) {
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
  /// `atOnce`; a change during a read is read again after it.
  private func scheduleAllChangesRead(_ id: AllChangesTab.ID, atOnce: Bool = false) {
    guard pendingAllChangesReads[id] == nil else { return }
    pendingAllChangesReads[id] = Task { @MainActor [weak self] in
      if !atOnce { try? await Task.sleep(for: Self.allChangesSettleDelay) }
      while !atOnce, !Task.isCancelled, let self,
        let due = allChangesReadLog.nextDue(id, costScale: filesOwed(by: id)),
        due > .now
      {
        try? await Task.sleep(until: due)
      }
      guard !Task.isCancelled, let self else { return }
      pendingAllChangesReads[id] = nil
      await readAllChangesTab(id)
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
    let (reading, filesRead) = await AllChangesReader.read(
      list,
      in: worktree.path,
      git: coordinator.git,
      diffAlgorithm: workspace.diffAlgorithm,
      since: fileTabBase(in: tab.worktreeID),
      previous: allChangesReadings[id],
      rereading: allChangesStaleFiles.take(id),
      imageRule: imageRule,
    )
    let isSuperseded = allChangesReadLog.isSuperseded(id)
    // Noted a file's worth, the next read waiting by the files it will read.
    let readsAgain = allChangesReadLog.finish(
      id,
      cost: started.duration(to: .now) / max(1, filesRead),
    )
    guard workspace.allChangesTab(id) != nil else { return }
    guard !isSuperseded else {
      if isAllChangesTabShown(id) { scheduleAllChangesRead(id) } else { allChangesReadLog.owe(id) }
      return
    }
    // Hidden while it ran, it would hold rows nobody sees; shown again it reads anew.
    guard isAllChangesTabShown(id) else {
      allChangesReadLog.owe(id)
      return
    }
    let previous = allChangesReadings[id]
    let before = allChangesDocument(of: id)?.text
    if setIfChanged(\.allChangesReadings[id], reading) {
      reanchorReview(in: tab, toFilesMovedSince: previous, in: reading)
      rerunFileFind(in: id, laidOutBefore: before)
    }
    if readsAgain { scheduleAllChangesRead(id) }
  }

  /// Each file whose rows moved has its comments, and the composer on it,
  /// follow their quotes, as a file tab's read does; a gone file's stay put.
  private func reanchorReview(
    in tab: AllChangesTab,
    toFilesMovedSince previous: AllChangesReading?,
    in reading: AllChangesReading,
  ) {
    let before = previous?.files.keyedByPath() ?? [:]
    let scope = fileTabScope(in: tab.worktreeID)
    for file in reading.files where file != before[file.path] {
      guard let rows = file.rows, file.reading?.isFileGone == false else { continue }
      reanchorReviewComments(
        onFile: file.path,
        in: tab.worktreeID,
        to: rows.lines,
        readUnder: scope,
      )
      reanchorReviewComposer(in: tab.id, onFile: file.path, to: rows.lines, readUnder: scope)
    }
  }

  /// The view's, once it has coloured a read's rows, which paces the next: a
  /// file's share, as the read's cost is noted.
  public func noteAllChangesHighlighted(_ id: AllChangesTab.ID, cost: Duration) {
    let files = allChangesReadings[id]?.files.count ?? 1
    allChangesReadLog.noteHighlightCost(cost / max(1, files), of: id)
  }

  /// How many files the next read reads: every file after a git change, else
  /// those an event or the list moved.
  private func filesOwed(by id: AllChangesTab.ID) -> Int {
    switch allChangesStaleFiles.pending(id) {
    case .everything: allChangesReadings[id]?.files.count ?? 1
    case .paths(let paths): paths.count
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
    allChangesScrolls = allChangesScrolls.filter { open.contains($0.key) }
    setIfChanged(
      \.allChangesCollapsedFiles,
      allChangesCollapsedFiles.filter { open.contains($0.key) },
    )
    setIfChanged(\.allChangesOpenedFolds, allChangesOpenedFolds.filter { open.contains($0.key) })
    setIfChanged(\.allChangesTopFiles, allChangesTopFiles.filter { open.contains($0.key) })
    setIfChanged(\.allChangesFileReveals, allChangesFileReveals.filter { open.contains($0.key) })
    allChangesDocuments = allChangesDocuments.filter { open.contains($0.key) }
  }
}
