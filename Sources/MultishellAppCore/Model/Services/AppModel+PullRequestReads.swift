import Foundation
import MultishellCore
import MultishellGitKit
import MultishellServices

extension AppModel {
  /// One list call for the whole project. A failure keeps the list before it,
  /// so a row keeps what it showed; see Docs/design/services.md.
  func readPullRequests(
    of project: Project,
    remotes: [GitRemote]?,
    after previous: ProjectPullRequests?,
  ) async -> ProjectPullRequests? {
    guard let (integration, host) = pullRequestHost(for: project) else { return nil }
    // A failed git read is not a repository without remotes.
    guard let remotes else { return previous }
    let changesBefore = remoteState.integrationChanges[project.id]
    var reading =
      previous.flatMap { $0.integration == integration ? $0 : nil }
      ?? ProjectPullRequests(integration: integration, pullRequests: [], remotes: remotes)
    // The host decides "not ours" from the remotes and its logins, so the
    // same remotes get the same answer until a login may have changed it.
    if reading.failure == .notHosted, reading.remotes == remotes,
      ServiceReadInterval.notHostedStands(since: reading.notHostedSince)
    {
      return reading
    }
    reading.remotes = remotes
    do {
      reading.pullRequests = try await host.pullRequests(in: project.path)
      reading.hasAnswered = true
      // Gone, or its integrations changed, while `gh` ran: nothing stands to date.
      if workspace.project(project.id) != nil,
        remoteState.integrationChanges[project.id] == changesBefore
      {
        remoteState.pullRequestsAnsweredAt[project.id] = .now
      }
      reading.failure = nil
      reading.notHostedSince = nil
    } catch {
      reading.failure = ServiceReadFailure(error)
      if reading.failure == .notHosted {
        reading.pullRequests = []
        reading.notHostedSince = .now
      }
    }
    return reading
  }
}
