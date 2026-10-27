import Foundation
import MultishellCore
import MultishellGitKit
import MultishellServices

extension AppModel {
  /// The providers whose install has the commands the reads use.
  var readableCIProviders: [ServiceIntegration: any CIProvider] {
    remoteState.connections.ciProviders.filter { !remoteState.unreadableProviders.contains($0.key) }
  }

  /// A connection for each tool on the login shell's PATH, sharing git's run
  /// log. None without git: both tools find the repository through it.
  func adoptServiceTools(on searchPath: String?, loginVariables: [String: String] = [:]) async {
    let detection = await runOnDispatch { ServiceToolDetection(searchPath: searchPath) }
    let adoption = ServiceToolAdoption(
      detection: detection,
      searchPath: searchPath,
      loginVariables: loginVariables,
      hasGit: coordinator != nil,
    )
    // The same tools found again: nothing to rebuild, and nothing redrawn.
    guard adoption != remoteState.adoption else { return }
    remoteState.adoption = adoption
    let connections =
      coordinator.map { coordinator in
        ServiceConnections(
          detection: detection,
          searchPath: searchPath,
          runLog: coordinator.git.runLog,
          loginVariables: loginVariables,
        )
      } ?? .empty
    // A provider new to this adoption is passed over until its version says
    // it can read, asked aside: a cold `circleci version` can take seconds.
    let unchecked = Set(connections.ciProviders.keys)
      .subtracting(remoteState.connections.ciProviders.keys)
    remoteState.toolDetection = detection
    remoteState.connections = connections
    setIfChanged(
      \.remoteState.unreadableProviders,
      remoteState.unreadableProviders.union(unchecked),
    )
    Task { await checkToolsCanRead() }
    setIfChanged(\.remoteState.toolStatuses, [:])
    remoteState.toolStatusAsk += 1
    // A page opened before the login shell's PATH arrived would wait forever;
    // asked aside, as `gh auth status` goes to the network.
    if remoteState.wantsToolStatuses { Task { await refreshServiceToolStatuses() } }
    dropReadingsWithoutATool()
    readFilesPanelIfItsKindChanged()
  }

  /// A tool gone from the path answers nothing more, so what it read goes.
  private func dropReadingsWithoutATool() {
    forgetPanelReadsWithoutAService(ofProjects: workspace.projects.map(\.id))
    let hosts = remoteState.connections.pullRequestHosts
    let orphanedLists = remoteState.pullRequests.filter { hosts[$0.value.integration] == nil }.keys
    let readable = readableCIProviders
    let orphanedRuns = remoteState.ciRuns.filter { readable[$0.value.integration] == nil }.keys
    for id in orphanedLists { forgetPullRequestReading(ofProject: id) }
    for id in orphanedRuns { forgetCIReading(ofProject: id) }
    for id in Set(orphanedLists).union(orphanedRuns) { recomputeWorktreeServices(ofProject: id) }
  }

  /// The project's pull request host: the first integration turned on here
  /// whose tool is installed.
  func pullRequestHost(for project: Project) -> (ServiceIntegration, any PullRequestHost)? {
    firstEnabled(of: remoteState.connections.pullRequestHosts, for: project)
  }

  /// The same for CI. Whether the repository runs on it is asked at the read.
  func ciProvider(for project: Project) -> (ServiceIntegration, any CIProvider)? {
    firstEnabled(of: readableCIProviders, for: project)
  }

  /// A provider found able to read is read at once, and the panel turns to
  /// its page where that was the one asked for.
  func checkToolsCanRead() async {
    let adoption = remoteState.adoption
    let connections = remoteState.connections
    let unreadable = await unreadableProviders(of: connections)
    // An adoption during the check asks its own tools, perhaps other binaries
    // under the same names; this answer is about the ones it replaced.
    guard remoteState.adoption == adoption else { return }
    let wasUnreadable = remoteState.unreadableProviders
    let fresh = wasUnreadable.subtracting(connections.ciProviders.keys).union(unreadable)
    guard setIfChanged(\.remoteState.unreadableProviders, fresh) else { return }
    dropReadingsWithoutATool()
    readFilesPanelIfItsKindChanged()
    guard !wasUnreadable.subtracting(fresh).isEmpty else { return }
    let projects = Array(projectsWithRowsInView())
    // In the background nothing is asked; the return to the front reads them.
    guard platform.isActive else {
      for id in projects { remoteState.readLog.markDue(id) }
      return
    }
    // Its runs at once, a few projects at a time; the pull requests are current.
    Task {
      await projects.mapConcurrentlyUnordered(width: Self.concurrentServiceReads) { id in
        await self.refreshServices(ofProject: id, readsPullRequests: false)
      }
    }
  }

  private func unreadableProviders(
    of connections: ServiceConnections
  ) async -> Set<ServiceIntegration> {
    var unreadable: Set<ServiceIntegration> = []
    for (integration, provider) in connections.ciProviders where await !provider.canRead() {
      unreadable.insert(integration)
    }
    return unreadable
  }

  private func firstEnabled<Connection>(
    of connections: [ServiceIntegration: Connection],
    for project: Project,
  ) -> (ServiceIntegration, Connection)? {
    let settings = ownSettings(of: project)
    for integration in ServiceIntegration.allCases where settings.enables(integration) {
      if let connection = connections[integration] { return (integration, connection) }
    }
    return nil
  }
}
