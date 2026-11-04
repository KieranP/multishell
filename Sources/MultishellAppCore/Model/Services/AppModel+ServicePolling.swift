import MultishellCore
import MultishellServices

/// The poll that reads every project in view whose services are due.
extension AppModel {
  /// A hung tool would hold git's rounds for its 30 s timeout, so the reads
  /// run beside them, one poll at a time.
  func startServicePoll(interval: Duration = ServiceReadInterval.poll) {
    // Launched in the background, as a login item, nothing is asked until
    // the app comes to the front.
    guard platform.isActive else { return }
    guard remoteState.servicePoll == nil else {
      // A return to the front mid-poll still reads what its shorter
      // interval makes due, once the poll ends.
      remoteState.nextPollInterval = min(remoteState.nextPollInterval ?? interval, interval)
      return
    }
    remoteState.servicePoll = Task { [weak self] in
      await self?.pollServices(interval: interval)
      guard let self else { return }
      remoteState.servicePoll = nil
      if let next = remoteState.nextPollInterval {
        remoteState.nextPollInterval = nil
        startServicePoll(interval: next)
      }
    }
  }

  /// Every project with a row in view whose services are due: the poll's, at
  /// `interval`, and sooner where a shown run is under way; see services.md.
  func pollServices(interval: Duration = ServiceReadInterval.poll) async {
    let now = ContinuousClock.now
    let due = projectsWithRowsInView().filter { id in
      // Never marked asked before a tool is there to ask, or the login
      // shell's PATH landing would wait out a whole interval.
      guard let project = workspace.project(id), hasServiceToAsk(project) else { return false }
      let interval =
        hasRunUnderWay(inProject: id) ? min(interval, ServiceReadInterval.underWay) : interval
      return remoteState.readLog.isDue(id, at: now, interval: interval)
    }
    await due.mapConcurrentlyUnordered(width: Self.concurrentServiceReads) { id in
      await self.refreshServices(ofProject: id)
    }
    await pollPanelServices()
  }

  private func hasRunUnderWay(inProject id: Project.ID) -> Bool {
    workspace.worktrees(of: id).contains { worktree in
      remoteState.worktrees[worktree.id]?.ciRun?.isUnderWay == true
    }
  }
}
