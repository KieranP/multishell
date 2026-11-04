import Foundation
import MultishellCore
import MultishellServices

extension AppModel {
  public func isIntegrationEnabled(_ integration: ServiceIntegration, for project: Project) -> Bool
  {
    ownSettings(of: project).enables(integration)
  }

  public func setIntegration(
    _ integration: ServiceIntegration,
    isEnabled: Bool,
    for project: Project,
  ) {
    var settings = ownSettings(of: project)
    settings.setIntegration(integration, isEnabled: isEnabled)
    setSettings(settings, for: project)
  }

  /// Turned off, what it read goes at once; turned on, it is read at once.
  /// Here, not in `setIntegration`, so a control write does the same.
  func applyIntegrationChanges(
    from previous: ProjectSettings,
    to settings: ProjectSettings,
    of id: Project.ID,
  ) {
    let changed = ServiceIntegration.allCases.filter { integration in
      previous.enables(integration) != settings.enables(integration)
    }
    guard !changed.isEmpty else { return }
    remoteState.integrationChanges[id, default: 0] += 1
    for integration in changed where !settings.enables(integration) {
      if remoteState.pullRequests[id]?.integration == integration {
        forgetPullRequestReading(ofProject: id)
      }
      if remoteState.ciRuns[id]?.integration == integration { forgetCIReading(ofProject: id) }
    }
    recomputeWorktreeServices(ofProject: id)
    forgetPanelReadsWithoutAService(ofProjects: [id])
    guard changed.contains(where: settings.enables) else { return }
    // As every read: in the background, the return to the front reads it.
    if platform.isActive {
      Task { await refreshServices(ofProject: id) }
    } else {
      remoteState.readLog.markDue(id)
    }
  }

  public func integrationAvailability(_ integration: ServiceIntegration) -> IntegrationAvailability
  {
    guard remoteState.connections.isStandIn || remoteState.toolDetection.isInstalled(integration)
    else { return .notInstalled }
    guard coordinator != nil else { return .needsGit }
    return remoteState.toolStatuses[integration].map(IntegrationAvailability.tool) ?? .checking
  }

  /// Asked as the page opens: each asks the service, so never on the poll.
  /// The page has closed: tools found later wait for it to open again.
  public func stopAskingToolStatuses() {
    remoteState.wantsToolStatuses = false
  }

  public func refreshServiceToolStatuses() async {
    remoteState.wantsToolStatuses = true
    remoteState.toolStatusAsk += 1
    let ask = remoteState.toolStatusAsk
    var asks: [(ServiceIntegration, @Sendable () async -> ServiceToolStatus)] = []
    for (integration, host) in remoteState.connections.pullRequestHosts {
      asks.append((integration, { await host.toolStatus() }))
    }
    for (integration, provider) in remoteState.connections.ciProviders {
      asks.append((integration, { await provider.toolStatus() }))
    }
    let statuses = await asks.mapConcurrentlyUnordered(width: max(asks.count, 1)) {
      integration,
      ask in
      (integration, await ask())
    }
    guard ask == remoteState.toolStatusAsk else { return }
    setIfChanged(\.remoteState.toolStatuses, Dictionary(keepingFirst: statuses))
  }

  /// From the last read, so the page stats nothing as it draws.
  public func integrationRepositoryFit(
    _ integration: ServiceIntegration,
    for project: Project,
  ) -> IntegrationRepositoryFit {
    if let reading = remoteState.pullRequests[project.id], reading.integration == integration,
      reading.failure == .notHosted
    {
      return .notHosted
    }
    if let reading = remoteState.ciRuns[project.id], reading.integration == integration {
      if !reading.isConfigured { return .notConfigured }
      if reading.failure == .notHosted { return .notHosted }
    }
    return .unknown
  }
}
