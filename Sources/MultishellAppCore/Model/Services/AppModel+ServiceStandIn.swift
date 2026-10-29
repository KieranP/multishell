import Foundation
import MultishellCore
import MultishellServices

/// `debug services stand-in`: answers in place of `gh` and `circleci`, through
/// every read the tools' answers go through; see Docs/design/services.md.
extension AppModel {
  /// A stand-in, or the tools back with `nil`; returns once the rows in view
  /// and an open services page are read through it, the rest left due.
  func standInServices(_ standIn: ServiceStandIn?) async {
    guard standIn != nil || remoteState.standIn != nil else { return }
    remoteState.standIn = standIn
    installServiceConnections(checksToolsAside: false)
    // Dropped before the tools are checked, which can take seconds, so no row
    // shows the other side's answer meanwhile.
    let projects = workspace.projects.map(\.id)
    for id in projects {
      forgetPullRequestReading(ofProject: id)
      forgetCIReading(ofProject: id)
      recomputeWorktreeServices(ofProject: id)
    }
    setIfChanged(\.remoteState.checks, [:])
    setIfChanged(\.remoteState.ciHistories, [:])
    pruneRunDetails()
    // Its own reads below cover what turns readable, which would read it twice.
    await checkToolsCanRead(readsWhatTurnsReadable: false)
    let shown = projectsWithRowsInView()
    for id in projects where !shown.contains(id) { remoteState.readLog.markDue(id) }
    await Array(shown).mapConcurrentlyUnordered(width: Self.concurrentServiceReads) { id in
      await self.readServicesOnceAnyUnderWayEnds(ofProject: id)
    }
    await readServicesPageOnceAnyUnderWayEnds()
  }

  /// A read under way began from what was replaced, so it is outwaited, and
  /// this one asked again where another began meanwhile.
  private func readServicesOnceAnyUnderWayEnds(ofProject id: Project.ID) async {
    // The helper hung up: the poll reads it in time, nobody waiting on this.
    while !Task.isCancelled {
      await readEnded(
        awaiting: { remoteState.readLog.awaitEnd(of: id, as: $0, $1) },
        ending: { [weak self] in self?.remoteState.readLog.endWait($0, of: id) },
      )
      guard !Task.isCancelled else { return }
      if await refreshServices(ofProject: id, queuesBehindOneUnderWay: false) { return }
    }
  }

  /// Read whether the app is in front or not, the request having asked; asked
  /// afresh each turn, as the page or its worktree may change while it waits.
  private func readServicesPageOnceAnyUnderWayEnds() async {
    while !Task.isCancelled, isFilesPanelOnScreen, let worktree = filesPanelWorktree,
      !shownFilesPanelMode.listsFiles
    {
      let read = PanelRead(worktree: worktree.id, page: shownFilesPanelMode)
      await readEnded(
        awaiting: { remoteState.panelReadLog.awaitEnd(of: read, as: $0, $1) },
        ending: { [weak self] in self?.remoteState.panelReadLog.endWait($0, of: read) },
      )
      guard !Task.isCancelled else { return }
      if await readPanelServices(of: worktree.id) { return }
    }
  }

  /// Returns once a read under way ends, or the helper hangs up: `awaiting` files
  /// the waiter under its token, and `ending` resumes that one waiter early.
  private func readEnded(
    awaiting: (UUID, CheckedContinuation<Void, Never>) -> Void,
    ending: @escaping @MainActor @Sendable (UUID) -> Void,
  ) async {
    let token = UUID()
    await withTaskCancellationHandler {
      await withCheckedContinuation { awaiting(token, $0) }
    } onCancel: {
      Task { @MainActor in ending(token) }
    }
  }
}
