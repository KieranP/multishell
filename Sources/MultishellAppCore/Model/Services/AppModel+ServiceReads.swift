import Foundation
import MultishellCore
import MultishellGitKit
import MultishellServices

extension AppModel {
  static var concurrentServiceReads: Int { 4 }

  /// What a row, its popover and the panel's pages draw of the services.
  public func services(of worktree: Worktree) -> WorktreeServices {
    remoteState.worktrees[worktree.id] ?? .empty
  }

  public func branchStanding(of worktree: Worktree) -> BranchStanding {
    BranchStanding(mergeState: mergeState(of: worktree), services: services(of: worktree))
  }

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

  /// The project's pull requests and runs, read at once, or again after one under
  /// way; `false` where that one took it or a tool change dropped its answer.
  @discardableResult
  func refreshServices(
    ofProject id: Project.ID,
    readsPullRequests: Bool = true,
    queuesBehindOneUnderWay: Bool = true,
  ) async -> Bool {
    guard let project = workspace.project(id), !missingProjects.contains(id),
      hasServiceToAsk(project)
    else { return true }
    guard remoteState.readLog.begin(id, at: .now) else {
      if queuesBehindOneUnderWay {
        remoteState.rereads[id] = remoteState.rereads[id] == true || readsPullRequests
      }
      return false
    }
    defer {
      remoteState.readLog.finish(id)
      if let readsPullRequests = remoteState.rereads.removeValue(forKey: id) {
        // Gone behind while it read: the return to the front reads it.
        if platform.isActive {
          Task { await refreshServices(ofProject: id, readsPullRequests: readsPullRequests) }
        } else {
          remoteState.readLog.markDue(id)
        }
      }
    }
    let changesBefore = remoteState.integrationChanges[id]
    let remotes = await coordinator?.git.remotes(project)
    let previousPullRequests = remoteState.pullRequests[id]
    async let pullRequests =
      readsPullRequests
      ? readPullRequests(of: project, remotes: remotes, after: previousPullRequests)
      : previousPullRequests
    async let ciRuns = readCIRuns(of: project, remotes: remotes, after: remoteState.ciRuns[id])
    let (readPullRequests, readCIRuns) = await (pullRequests, ciRuns)
    // Gone while the tools ran, or its integrations changed: what was read
    // began from what is no longer asked, so a re-read reads afresh.
    guard let current = workspace.project(id) else { return true }
    guard remoteState.integrationChanges[id] == changesBefore else {
      // As every read: in the background, the return to the front reads it.
      if platform.isActive {
        remoteState.rereads[id] = true
      } else {
        remoteState.readLog.markDue(id)
      }
      return false
    }
    let keptPullRequests = readPullRequests.flatMap { reading in
      pullRequestHost(for: current)?.0 == reading.integration ? reading : nil
    }
    let keptCIRuns = readCIRuns.flatMap { reading in
      ciProvider(for: current)?.0 == reading.integration ? reading : nil
    }
    setIfChanged(\.remoteState.pullRequests[id], keptPullRequests)
    setIfChanged(\.remoteState.ciRuns[id], keptCIRuns)
    // A read whose tool went while it ran has dated an answer nothing shows.
    if keptPullRequests == nil { forgetPullRequestReading(ofProject: id) }
    if keptCIRuns == nil { forgetCIReading(ofProject: id) }
    recomputeWorktreeServices(ofProject: id)
    await readChangesPastHead(ofProject: id, asksAgain: true)
    return true
  }

  /// A burst of upstream moves, a push or a pull, becomes one read once it
  /// settles.
  func scheduleServicesRead(of id: Project.ID) {
    // In the background nothing is asked; the return to the front reads it,
    // however recent the last read.
    guard platform.isActive else {
      remoteState.readLog.markDue(id)
      return
    }
    guard remoteState.pendingReads[id] == nil else { return }
    remoteState.pendingReads[id] = Task { @MainActor [weak self] in
      try? await Task.sleep(for: Self.changeSettleDelay)
      guard !Task.isCancelled, let self else { return }
      remoteState.pendingReads[id] = nil
      // Gone to the background while it settled: the return reads it.
      guard platform.isActive else {
        remoteState.readLog.markDue(id)
        return
      }
      await refreshServices(ofProject: id)
    }
  }

  /// Where each worktree's branch is published, from a branch scan. A move after
  /// the first read re-reads the services: a push is what a run starts on.
  func recordBranchUpstreams(_ upstreams: [String: BranchUpstream], of id: Project.ID) {
    let trunk = workspace.project(id).map(defaultBranchName(of:))
    var fresh = remoteState.upstreams
    for worktree in workspace.worktrees(of: id) {
      // A branch cut from the trunk tracks it until first pushed; the trunk's
      // pull requests and runs are not its own.
      fresh[worktree.id] = worktree.branch.flatMap { branch in
        upstreams[branch].flatMap { $0.branch == trunk && branch != trunk ? nil : $0 }
      }
    }
    let moved = setIfChanged(\.remoteState.upstreams, fresh)
    recomputeWorktreeServices(ofProject: id)
    if moved, remoteState.readLog.hasAsked(id) { scheduleServicesRead(of: id) }
  }

  /// Each of the project's rows matched against what its services last said.
  func recomputeWorktreeServices(ofProject id: Project.ID) {
    let worktrees = workspace.worktrees(of: id)
    let ids = Set(worktrees.map(\.id))
    var fresh = remoteState.worktrees.filter { !ids.contains($0.key) }
    for worktree in worktrees {
      let upstream = remoteState.upstreams[worktree.id]
      // A branch asked alone answers when it last did, not when the project did.
      let failedAlone = upstream.flatMap { remoteState.ciRuns[id]?.branchFailures[$0.branch] }
      let ciAnsweredAt =
        failedAlone == nil
        ? remoteState.ciRunsAnsweredAt[id]
        : upstream.flatMap { remoteState.ciBranchesAnsweredAt[id]?[$0.branch] }
      fresh[worktree.id] = WorktreeServices(
        upstream: upstream,
        localTip: scannedBranchTips[worktree.id] ?? worktree.head,
        localBranch: worktree.branch,
        pullRequests: remoteState.pullRequests[id],
        ciRuns: remoteState.ciRuns[id],
        answeredAt: (remoteState.pullRequestsAnsweredAt[id], ciAnsweredAt),
        changesPastHead: remoteState.changesPastHead[id] ?? [:],
      )
    }
    setIfChanged(\.remoteState.worktrees, fresh)
    let asked = Set(worktrees.compactMap { fresh[$0.id]?.changesPastMergedHead })
    remoteState.changesPastHead[id] = remoteState.changesPastHead[id]?
      .filter { asked.contains($0.key) }
    remoteState.unanswerableChangesPastHead[id]?.formIntersection(asked)
    pruneRunDetails()
  }

  /// A run's workflows and report are kept while a row or the panel's own
  /// history shows it; another worktree's history keeps only its list.
  func pruneRunDetails() {
    let panelHistory = filesPanelWorktree.flatMap { remoteState.ciHistories[$0.id] }
    let shownRuns = Set(remoteState.worktrees.values.compactMap(\.ciRun?.id))
      .union(panelHistory?.runs.map(\.id) ?? [])
    setIfChanged(
      \.remoteState.ciWorkflows,
      remoteState.ciWorkflows.filter { shownRuns.contains($0.key) },
    )
    setIfChanged(
      \.remoteState.failureReports,
      remoteState.failureReports.filter { shownRuns.contains($0.key) },
    )
    remoteState.workflowsReadAt = remoteState.workflowsReadAt.filter { shownRuns.contains($0.key) }
    remoteState.reportsReadAt = remoteState.reportsReadAt.filter { shownRuns.contains($0.key) }
  }

  /// What was matched to a worktree's branch: gone with the worktree, or with
  /// a checkout onto another branch until the next scan matches that one.
  func forgetBranchServices(of ids: Set<Worktree.ID>) {
    guard !ids.isEmpty else { return }
    setIfChanged(\.remoteState.worktrees, remoteState.worktrees.filter { !ids.contains($0.key) })
    setIfChanged(\.remoteState.upstreams, remoteState.upstreams.filter { !ids.contains($0.key) })
  }

  /// A project's services are its own and go with it.
  func forgetServices(ofProject id: Project.ID) {
    remoteState.branchStartPoints[id] = nil
    remoteState.branchScansBegun[id] = nil
    forgetPullRequestReading(ofProject: id)
    forgetCIReading(ofProject: id)
    remoteState.readLog.forget(id)
    remoteState.rereads[id] = nil
    remoteState.changesPastHead[id] = nil
    remoteState.changesPastHeadReads[id] = nil
    remoteState.unanswerableChangesPastHead[id] = nil
    remoteState.pendingReads.removeValue(forKey: id)?.cancel()
  }

  /// A reading goes with when it was answered, or a later failure would date
  /// itself by an answer no longer shown.
  func forgetPullRequestReading(ofProject id: Project.ID) {
    setIfChanged(\.remoteState.pullRequests[id], nil)
    remoteState.pullRequestsAnsweredAt[id] = nil
  }

  func forgetCIReading(ofProject id: Project.ID) {
    setIfChanged(\.remoteState.ciRuns[id], nil)
    remoteState.ciRunsAnsweredAt[id] = nil
    remoteState.ciBranchesAnsweredAt[id] = nil
  }

  func projectsWithRowsInView() -> Set<Project.ID> {
    var ids = Set(sidebarRowIDs().compactMap { workspace.worktree($0)?.projectID })
    if let selected = workspace.selectedWorktreeID,
      let project = workspace.worktree(selected)?.projectID
    {
      ids.insert(project)
    }
    return ids.subtracting(missingProjects)
  }

  private func hasServiceToAsk(_ project: Project) -> Bool {
    pullRequestHost(for: project) != nil || ciProvider(for: project) != nil
  }

  private func hasRunUnderWay(inProject id: Project.ID) -> Bool {
    workspace.worktrees(of: id).contains { worktree in
      remoteState.worktrees[worktree.id]?.ciRun?.isUnderWay == true
    }
  }
}
