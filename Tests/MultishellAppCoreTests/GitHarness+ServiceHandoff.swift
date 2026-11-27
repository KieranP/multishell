import Foundation
import TestScratch
import Testing

@testable import MultishellAppCore
@testable import MultishellCore
@testable import MultishellServices

extension GitHarness {
  static let failingCheckLink = URL(string: "https://github.com/me/demo/actions/runs/7/job/9")!

  private static let failedRunWorkflows = [
    CIWorkflow(
      name: "build",
      status: .failed,
      jobs: [
        CIJob(id: "11", name: "lint", status: .passed),
        CIJob(id: "12", name: "test-macos", status: .failed),
      ],
    )
  ]

  /// A PR page Send for `worktree` is reading its checks' logs.
  func readsLogs(of worktree: Worktree) -> Bool {
    if case .readingLogs = model.handoff.sendPhases[worktree.id] { true } else { false }
  }

  /// `feat` pushed with pull request #9 open, `test` failing on it, one thread
  /// unresolved, the PR page read and a Claude Code tab open in it.
  func showingAFailingPullRequest() async throws
    -> (Worktree, FakePullRequestHost, TerminalSession)
  {
    let (host, _) = connectServices()
    try await addOrigin()
    let feat = try await createWorktree(onBranch: "feat")
    try await pushToGitHubOrigin(feat)
    let tip = try await tip(of: feat)
    host.answer(.success([.sample(number: 9, headBranch: "feat", headCommit: tip)]))
    host.answerChecks([.sample(name: "test", status: .failed, link: Self.failingCheckLink)])
    host.answerLog(of: Self.failingCheckLink, .success("error: boom"))
    host.answerThreads(.success([.sample()]))
    await model.refreshBranchScan(of: project)
    await model.refreshServices(ofProject: project.id)
    model.select(feat)
    model.setShowsFilesPanel(true)
    model.setFilesPanelMode(.pullRequest)
    try await waitUntil {
      model.remoteState.checks[feat.id]?.checks != nil
        && model.remoteState.threads[feat.id]?.threads != nil
    }
    return (feat, host, try openClaudeTab(in: feat))
  }

  /// `feat` pushed, its newest run failed in `test-macos` with the fake's
  /// report read, and a Claude Code tab open in it.
  func showingAFailedRun() async throws -> (Worktree, TerminalSession, FakeCIProvider) {
    let (_, provider) = connectServices()
    try writeCIConfiguration()
    try await addOrigin()
    let feat = try await createWorktree(onBranch: "feat")
    try await pushToGitHubOrigin(feat)
    let tip = try await tip(of: feat)
    let run = CIRun.sample(id: "r2", branch: "feat", commit: tip, status: .failed)
    provider.answer(recent: [run], workflows: Self.failedRunWorkflows, history: [run])
    await model.refreshBranchScan(of: project)
    await model.refreshServices(ofProject: project.id)
    model.select(feat)
    model.setShowsFilesPanel(true)
    model.setFilesPanelMode(.ciRuns)
    try await waitUntil {
      model.remoteState.failureReports["r2"] != nil
        && model.remoteState.ciWorkflows["r2"] != nil
    }
    return (feat, try openClaudeTab(in: feat), provider)
  }

  private func openClaudeTab(in worktree: Worktree) throws -> TerminalSession {
    store.openTab(in: worktree.id, title: "claude", agentID: AgentCatalogue.claudeID)
    model.reconcileSessions(takingFocus: true)
    return try #require(model.workspace.sessions(in: worktree.id).first { $0.agentID != nil })
  }
}
