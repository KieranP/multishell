import Foundation
import MultishellCore
import MultishellGitKit
import MultishellServices

extension AppModel {
  /// The provider whose run the row shows, for the menu's item naming it.
  public func ciMenuIntegration(for worktree: Worktree) -> ServiceIntegration? {
    let services = services(of: worktree)
    return services.ciRun == nil ? nil : services.ciIntegration
  }

  /// The branch by its name on the remote: the panel can show a run its
  /// history found where the row has none.
  public func openCIRuns(of worktree: Worktree) async {
    guard let project = workspace.project(worktree.projectID),
      let (integration, provider) = ciProvider(for: project),
      let upstream = remoteState.upstreams[worktree.id]
    else { return }
    do {
      try await provider.openRuns(onBranch: upstream.branch, in: worktree.path)
    } catch {
      present(ServiceOpenFailure(integration: integration, underlying: error))
    }
  }

  public func openCIJob(_ job: CIJob, of worktree: Worktree) async {
    guard let id = job.id, let project = workspace.project(worktree.projectID),
      let (integration, provider) = ciProvider(for: project)
    else { return }
    do {
      try await provider.openJob(id: id, in: worktree.path)
    } catch {
      present(ServiceOpenFailure(integration: integration, underlying: error))
    }
  }
}
