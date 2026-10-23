import Foundation
import MultishellCore
import MultishellGitKit

/// Keeping each file tab's rows current with its file and its git; see
/// Docs/design/files.md.
extension AppModel {
  /// A burst of saves becomes one read: 0.15 s of FSEvents latency, then this.
  private static var fileTabSettleDelay: Duration { .milliseconds(75) }

  /// In front of its group, in the worktree in view.
  private func isFileTabShown(_ id: FileTab.ID) -> Bool {
    guard let tab = workspace.fileTab(id), tab.worktreeID == worktreeIDInView else { return false }
    return workspace.group(tab.groupID)?.shownTabID == id
  }

  /// A shown tab reads again once the burst settles; a hidden one is owed a
  /// read for when shown, but a deletion strikes its title at once.
  func noteFileTabChanged(_ id: FileTab.ID) {
    guard workspace.fileTab(id) != nil else { return }
    if isFileTabShown(id), platform.isWorkspaceWindowVisible {
      scheduleFileTabRead(id)
      return
    }
    fileTabReadLog.owe(id)
    strikeIfGoneOrBack(id)
  }

  /// Every file tab, as when the diff algorithm changes what each counts.
  func noteEveryFileTabChanged() {
    fileTabReadLog.forgetPace()
    for tab in workspace.fileTabs { noteFileTabChanged(tab.id) }
  }

  /// The tabs on screen that hold nothing to show, or were owed a read while hidden.
  func readShownFileTabs() {
    guard platform.isWorkspaceWindowVisible, let worktree = worktreeIDInView else { return }
    for group in workspace.groups(in: worktree) {
      guard let id = group.shownTabID, workspace.fileTab(id) != nil,
        !holdsContent(id) || fileTabReadLog.owed.contains(id)
      else { continue }
      // A first read running already is enough; a change owed meanwhile is not.
      guard !fileTabReadLog.isReading(id) else {
        if fileTabReadLog.owed.contains(id) { fileTabReadLog.askAgain(id) }
        continue
      }
      // A tab coming into view holding nothing is read now, not at its pace.
      let isWaitedFor = !holdsContent(id)
      scheduleFileTabRead(id, atOnce: isWaitedFor)
    }
  }

  private func holdsContent(_ id: FileTab.ID) -> Bool {
    fileTabReadings[id].map { !$0.content.isReleased } ?? false
  }

  /// A hidden tab keeps its dot and strike, and a gone file's rows, the last
  /// it showed; see files.md. Its waiting read is owed instead.
  func releaseHiddenFileTabs() {
    for tab in workspace.fileTabs where !isFileTabShown(tab.id) {
      if let task = pendingFileTabReads.removeValue(forKey: tab.id) {
        task.cancel()
        fileTabReadLog.owe(tab.id)
      }
      guard let reading = fileTabReadings[tab.id], case .text = reading.content,
        !reading.isFileGone, !fileTabReadLog.isReading(tab.id)
      else { continue }
      let released = FileTabContent.released(changeKind: changeKind(of: tab))
      fileTabReadings[tab.id] = FileTabReading(content: released, isFileGone: false)
    }
  }

  /// One read per tab at a time, after the settle and once its pace allows, or
  /// `atOnce`; a change during a read is read again after it.
  private func scheduleFileTabRead(_ id: FileTab.ID, atOnce: Bool = false) {
    guard pendingFileTabReads[id] == nil else { return }
    pendingFileTabReads[id] = Task { @MainActor [weak self] in
      if !atOnce { try? await Task.sleep(for: Self.fileTabSettleDelay) }
      while !atOnce, !Task.isCancelled, let due = self?.fileTabReadLog.nextDue(id), due > .now {
        try? await Task.sleep(until: due)
      }
      guard !Task.isCancelled, let self else { return }
      pendingFileTabReads[id] = nil
      await readFileTab(id)
    }
  }

  func readFileTab(_ id: FileTab.ID) async {
    guard let coordinator, let tab = workspace.fileTab(id),
      let worktree = workspace.worktree(tab.worktreeID)
    else { return }
    guard !fileTabReadLog.isReading(id) else {
      fileTabReadLog.askAgain(id)
      return
    }
    fileTabReadLog.begin(id)
    let started = ContinuousClock.now
    let reading = await FileTabReader.read(
      path: tab.path,
      in: worktree.path,
      git: coordinator.git,
      diffAlgorithm: workspace.diffAlgorithm,
      previous: fileTabReadings[id],
    )
    let readsAgain = fileTabReadLog.finish(id, cost: started.duration(to: .now))
    guard workspace.fileTab(id) != nil else { return }
    setIfChanged(\.fileTabReadings[id], reading)
    // Hidden while it ran, its rows would wait for the next reconcile.
    releaseHiddenFileTabs()
    rerunFileFind(in: id)
    if readsAgain {
      if isFileTabShown(id) { scheduleFileTabRead(id) } else { fileTabReadLog.owe(id) }
    }
    // Hidden meanwhile, its file may have gone since this read looked.
    if fileTabReadLog.owed.contains(id) { strikeIfGoneOrBack(id) }
  }

  /// A hidden tab's title follows its file both ways, read since launch or
  /// not; the `lstat` runs off the main actor, a dead mount able to hold it.
  private func strikeIfGoneOrBack(_ id: FileTab.ID) {
    guard let tab = workspace.fileTab(id), let worktree = workspace.worktree(tab.worktreeID)
    else { return }
    let url = worktree.path.appending(path: tab.path)
    Task { @MainActor [weak self] in
      let isGone = await runOnDispatch { FileSignature.of(url) == nil }
      guard let self, workspace.fileTab(id) != nil else { return }
      let current = fileTabReadings[id]
      guard isGone != (current?.isFileGone ?? false) else { return }
      let content: FileTabContent =
        switch current?.content {
        case .text(let rows) where isGone && rows.holdsTextOnDisk: .text(rows.lastTextOnDisk())
        case let content?: content
        case nil: .missing
        }
      // A file back on a hidden tab lets go of the rows kept from before, its
      // dot following the status: those rows are no diff of what came back.
      let isBackWhileHidden = !isGone && !isFileTabShown(id)
      let kept = isBackWhileHidden ? FileTabContent.releasedFollowingStatus : content
      setIfChanged(\.fileTabReadings[id], FileTabReading(content: kept, isFileGone: isGone))
      rerunFileFind(in: id)
    }
  }

  /// The view's, once it has coloured a read's rows, which paces the next.
  public func noteFileTabHighlighted(_ id: FileTab.ID, cost: Duration) {
    fileTabReadLog.noteHighlightCost(cost, of: id)
  }

  /// A closed tab's rows, reads, selection, scroll and requests go with it. Run
  /// from the reconcile.
  func pruneFileTabs() {
    let open = Set(workspace.fileTabs.map(\.id))
    setIfChanged(\.fileTabReadings, fileTabReadings.filter { open.contains($0.key) })
    for (id, task) in pendingFileTabReads where !open.contains(id) {
      task.cancel()
      pendingFileTabReads[id] = nil
    }
    fileTabReadLog.keep(only: open)
    fileTabSelections = fileTabSelections.filter { open.contains($0.key) }
    fileTabScrolls = fileTabScrolls.filter { open.contains($0.key) }
    fileFindsShown = fileFindsShown.filter { open.contains($0.key) }
    fileTabSteppedChangeAnchors = fileTabSteppedChangeAnchors.filter { open.contains($0.key) }
    if let request = fileTabFocusRequest, !open.contains(request) { fileTabFocusRequest = nil }
    setIfChanged(\.changeStepRequests, changeStepRequests.filter { open.contains($0.key) })
    setIfChanged(\.fileTabChangeSteps, fileTabChangeSteps.filter { open.contains($0.key) })
  }
}
