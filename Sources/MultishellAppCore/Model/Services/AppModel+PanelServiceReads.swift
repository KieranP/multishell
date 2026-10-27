import Foundation
import MultishellCore
import MultishellGitKit
import MultishellServices

extension AppModel {
  /// How many of a branch's runs the CI page lists.
  private static var ciHistoryLength: Int { 10 }

  /// The page the panel shows: a services' page whose tool is gone shows
  /// Files, rather than a page nothing can fill.
  public var shownFilesPanelMode: FilesPanelMode {
    switch workspace.filesPanelMode {
    case .ciRuns: showsCIPanelPage ? .ciRuns : .files
    case .pullRequest: showsPullRequestPanelPage ? .pullRequest : .files
    case .files, .changes: workspace.filesPanelMode
    }
  }

  /// The pull request page's tab, wherever a host's tool is installed.
  public var showsPullRequestPanelPage: Bool { !remoteState.connections.pullRequestHosts.isEmpty }

  public var showsCIPanelPage: Bool { !readableCIProviders.isEmpty }

  /// `nil` once a rerun has the run going again or passed.
  public func failureReport(of run: CIRun) -> CIFailureReport? {
    run.status == .failed ? remoteState.failureReports[run.id]?.value : nil
  }

  /// A page whose host or provider is turned off or gone keeps nothing it read,
  /// so its return does not draw the old checks or runs as current.
  func forgetPanelReadsWithoutAService(ofProjects ids: [Project.ID]) {
    let projects = ids.compactMap { workspace.project($0) }
    func worktrees(where lacks: (Project) -> Bool) -> Set<Worktree.ID> {
      Set(projects.filter(lacks).flatMap { workspace.worktrees(of: $0.id).map(\.id) })
    }
    let withoutHost = worktrees { pullRequestHost(for: $0) == nil }
    let withoutProvider = worktrees { ciProvider(for: $0) == nil }
    if !withoutHost.isEmpty {
      setIfChanged(
        \.remoteState.checks,
        remoteState.checks.filter { !withoutHost.contains($0.key) },
      )
    }
    if !withoutProvider.isEmpty {
      setIfChanged(
        \.remoteState.ciHistories,
        remoteState.ciHistories.filter { !withoutProvider.contains($0.key) },
      )
    }
    pruneRunDetails()
  }

  /// The panel's worktree, read at its interval while the page shows it, and
  /// at once where what it was read for has moved: a push, a new run.
  func pollPanelServices() async {
    guard isFilesPanelOnScreen, let worktree = filesPanelWorktree else { return }
    await readPanelServicesIfDue(of: worktree)
  }

  /// Arrowing through rows reads only the one the selection rests on.
  func schedulePanelServicesRead(of id: Worktree.ID) {
    remoteState.pendingPanelRead?.cancel()
    remoteState.pendingPanelRead = Task { @MainActor [weak self] in
      try? await Task.sleep(for: Self.changeSettleDelay)
      guard !Task.isCancelled, let self else { return }
      remoteState.pendingPanelRead = nil
      pruneRunDetails()
      guard let worktree = workspace.worktree(id) else { return }
      await readPanelServicesIfDue(of: worktree)
    }
  }

  /// A turn of the page or a selection reads only what is due, and only while
  /// frontmost, as the poll does: arrowing through rows would ask each.
  func readPanelServicesIfDue(of worktree: Worktree) async {
    guard !shownFilesPanelMode.listsFiles, platform.isActive else { return }
    let interval =
      panelHasSomethingUnderWay(worktree)
      ? ServiceReadInterval.underWay : ServiceReadInterval.poll
    let read = PanelRead(worktree: worktree.id, page: shownFilesPanelMode)
    let isDue = remoteState.panelReadLog.isDue(read, at: .now, interval: interval)
    guard isDue || panelReadingIsStale(worktree) else { return }
    await readPanelServices(of: worktree.id)
  }

  /// The pull request's checks or the branch's runs, whichever page shows;
  /// one read at a time per worktree and page.
  private func readPanelServices(of id: Worktree.ID) async {
    let page = shownFilesPanelMode
    let read = PanelRead(worktree: id, page: page)
    guard let worktree = workspace.worktree(id), remoteState.panelReadLog.begin(read, at: .now)
    else { return }
    defer { remoteState.panelReadLog.finish(read) }
    pruneRunDetails()
    switch page {
    case .pullRequest: await readChecks(of: worktree)
    case .ciRuns: await readCIHistory(of: worktree)
    case .files, .changes: break
    }
  }

  private func readChecks(of worktree: Worktree) async {
    guard let project = workspace.project(worktree.projectID),
      let (integration, host) = pullRequestHost(for: project),
      let pullRequest = services(of: worktree).shownPullRequest
    else {
      setIfChanged(\.remoteState.checks[worktree.id], nil)
      return
    }
    var reading =
      remoteState.checks[worktree.id].flatMap { reading in
        reading.pullRequestNumber == pullRequest.number ? reading : nil
      }
      ?? PullRequestChecks(
        pullRequestNumber: pullRequest.number,
        headCommit: pullRequest.headCommit,
        checks: nil,
      )
    let isSettled = pullRequest.state == .merged || pullRequest.state == .closed
    // A merged or closed one's checks no longer change once read at its head.
    if isSettled, reading.checks != nil, reading.headCommit == pullRequest.headCommit { return }
    // A failed read after a push must not leave the old head's checks standing.
    if reading.headCommit != pullRequest.headCommit { reading.checks = nil }
    reading.headCommit = pullRequest.headCommit
    do {
      reading.checks = try await host.checks(of: pullRequest, in: worktree.path)
      reading.failure = nil
    } catch {
      reading.failure = ServiceReadFailure(error)
    }
    // Gone, or its host turned off, while `gh` ran: nothing asks for it now.
    guard workspace.worktree(worktree.id) != nil,
      pullRequestHost(for: project)?.0 == integration
    else { return }
    setIfChanged(\.remoteState.checks[worktree.id], reading)
  }

  private func readCIHistory(of worktree: Worktree) async {
    guard let project = workspace.project(worktree.projectID),
      let (integration, provider) = ciProvider(for: project),
      let upstream = remoteState.upstreams[worktree.id],
      await providerRunsThere(provider, project: project)
    else {
      setIfChanged(\.remoteState.ciHistories[worktree.id], nil)
      return
    }
    var history =
      remoteState.ciHistories[worktree.id].flatMap { $0.branch == upstream.branch ? $0 : nil }
      ?? CIRunHistory(branch: upstream.branch, runs: [])
    history.askedForRun = services(of: worktree).ciRun?.id
    do {
      let remotes = remoteState.ciRuns[project.id]?.remotes ?? []
      history.runs = try await provider.runs(
        onBranch: upstream.branch,
        limit: Self.ciHistoryLength,
        in: project.path,
      )
      .filter { WorktreeServices.ran($0, inRepositoryOf: upstream, remotes: remotes) }
      forgetDetailsOfRerunRuns(history.runs)
      history.failure = nil
    } catch {
      history.failure = ServiceReadFailure(error)
    }
    guard workspace.worktree(worktree.id) != nil, ciProvider(for: project)?.0 == integration
    else { return }
    setIfChanged(\.remoteState.ciHistories[worktree.id], history)
    guard let newest = history.runs.first else { return }
    await readCIRunDetails(of: newest, in: project)
  }

  /// Before the project's first read, the page's own due read asks once.
  private func expectsCIHistory(_ worktree: Worktree) -> Bool {
    guard let reading = remoteState.ciRuns[worktree.projectID] else { return false }
    return remoteState.upstreams[worktree.id] != nil && reading.isConfigured
      && reading.failure != .notHosted
  }

  /// As the project's read found, or the disk before it reads: CI is asked only
  /// where the configuration file is, and not where the provider disowns it.
  private func providerRunsThere(_ provider: any CIProvider, project: Project) async -> Bool {
    guard let reading = remoteState.ciRuns[project.id] else {
      return await runsOn(provider, project: project)
    }
    return reading.isConfigured && reading.failure != .notHosted
  }

  /// Read before its interval where it is about a head or run no longer shown.
  func panelReadingIsStale(_ worktree: Worktree) -> Bool {
    let services = services(of: worktree)
    switch shownFilesPanelMode {
    case .pullRequest:
      // Another pull request on the same head has checks of its own.
      let checks = remoteState.checks[worktree.id]
      return services.shownPullRequest?.headCommit != checks?.headCommit
        || services.shownPullRequest?.number != checks?.pullRequestNumber

    case .ciRuns:
      // A history of the branch it followed before is no history at all, where
      // one is to be had: none for an unpushed branch or a provider not there.
      guard let history = ciHistory(of: worktree) else { return expectsCIHistory(worktree) }
      return services.ciRun.map { run in run.id != history.askedForRun } ?? false

    case .files, .changes:
      return false
    }
  }

  private func panelHasSomethingUnderWay(_ worktree: Worktree) -> Bool {
    switch shownFilesPanelMode {
    case .pullRequest:
      remoteState.checks[worktree.id]?.checks?.contains(where: \.status.isUnderWay) ?? false

    case .ciRuns:
      ciHistory(of: worktree)?.runs.first?.isUnderWay == true

    case .files, .changes:
      false
    }
  }
}
