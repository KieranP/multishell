import Foundation
import MultishellCore
import MultishellGitKit
import MultishellServices

extension AppModel {
  /// The providers whose install has the commands the reads use.
  var readableCIProviders: [ServiceIntegration: any CIProvider] {
    remoteState.connections.ciProviders.filter { !remoteState.unreadableProviders.contains($0.key) }
  }

  /// The stand-in's where there is one, else the adopted tools'; none before
  /// the login shell's PATH has been adopted, nor without git.
  private var connectionsToInstall: ServiceConnections {
    if let standIn = remoteState.standIn { return ServiceConnections(standIn: standIn) }
    guard let adoption = remoteState.adoption, let coordinator else { return .empty }
    return ServiceConnections(
      detection: adoption.detection,
      searchPath: adoption.searchPath,
      runLog: coordinator.git.runLog,
      loginVariables: adoption.loginVariables,
    )
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
    installServiceConnections(checksToolsAside: true)
  }

  /// `connectionsToInstall` in place of the last. `checksToolsAside` false leaves
  /// `checkToolsCanRead` to a caller that waits on it.
  func installServiceConnections(checksToolsAside: Bool) {
    let connections = connectionsToInstall
    // A provider new to this adoption is passed over until its version says
    // it can read, asked aside: a cold `circleci version` can take seconds.
    let isSameKind = connections.isStandIn == remoteState.connections.isStandIn
    let unchecked = Set(connections.ciProviders.keys)
      .subtracting(isSameKind ? Set(remoteState.connections.ciProviders.keys) : [])
    remoteState.toolDetection = remoteState.adoption?.detection ?? .empty
    remoteState.connections = connections
    remoteState.connectionsInstalled += 1
    // A read under way asked the tools these replace, so its answer is dropped.
    for project in workspace.projects {
      remoteState.integrationChanges[project.id, default: 0] += 1
    }
    setIfChanged(
      \.remoteState.unreadableProviders,
      remoteState.unreadableProviders.union(unchecked),
    )
    if checksToolsAside { Task { await checkToolsCanRead() } }
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
  func checkToolsCanRead(readsWhatTurnsReadable: Bool = true) async {
    let installed = remoteState.connectionsInstalled
    let connections = remoteState.connections
    let unreadable = await unreadableProviders(of: connections)
    // An install during the check, an adoption's or a stand-in's, asks its own
    // providers; this answer is about the ones it replaced.
    guard remoteState.connectionsInstalled == installed else { return }
    let wasUnreadable = remoteState.unreadableProviders
    let fresh = wasUnreadable.subtracting(connections.ciProviders.keys).union(unreadable)
    guard setIfChanged(\.remoteState.unreadableProviders, fresh) else { return }
    dropReadingsWithoutATool()
    readFilesPanelIfItsKindChanged()
    guard readsWhatTurnsReadable, !wasUnreadable.subtracting(fresh).isEmpty else { return }
    let projects = Array(projectsWithRowsInView())
    // In the background nothing is asked; the return to the front reads them.
    guard platform.isActive else {
      for id in projects { remoteState.readLog.markDue(id) }
      return
    }
    // Its runs at once, a few projects at a time; the pull requests too where
    // none answered yet, as this read marks the project asked.
    let unanswered = Set(projects.filter { remoteState.pullRequests[$0]?.hasAnswered != true })
    Task {
      await projects.mapConcurrentlyUnordered(width: Self.concurrentServiceReads) { id in
        await self.refreshServices(ofProject: id, readsPullRequests: unanswered.contains(id))
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
