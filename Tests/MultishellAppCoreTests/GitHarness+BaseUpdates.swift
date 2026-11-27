import Foundation
import TestSupport
import Testing

@testable import MultishellAppCore
@testable import MultishellCore
@testable import MultishellGitKit

extension GitHarness {
  /// A `feature` worktree with a commit of its own, and `origin/main` one commit
  /// past where it was cut. Both write README.md where `conflicting`.
  func featureBehindOrigin(conflicting: Bool = false) async throws -> Worktree {
    try await addOrigin()
    let feature = try await createWorktree(onBranch: "feature")
    var featureFiles = ["feature.txt": "feature\n"]
    var landedFiles = ["landed.txt": "landed\n"]
    if conflicting {
      featureFiles["README.md"] = "from feature\n"
      landedFiles["README.md"] = "from main\n"
    }
    try await TestRepository.commit(
      "feature work",
      files: featureFiles,
      in: feature.path,
      using: git,
    )
    try await TestRepository.commit("landed", files: landedFiles, in: project.path, using: git)
    _ = try await git.run(["push", "-q", "origin", "main"], in: project.path)
    await model.refreshBranchScan(of: project)
    await model.refreshStatus(of: feature.id, forced: true)
    return feature
  }

  /// Claude in a tab of its own there, reporting it is working where asked.
  func openAgentTab(in worktree: Worktree, working: Bool) throws -> TerminalSession {
    model.select(worktree)
    store.openTab(in: worktree.id, title: "claude", agentID: AgentCatalogue.claudeID)
    model.reconcileSessions(takingFocus: true)
    let session = try #require(
      model.workspace.sessions(in: worktree.id).first { $0.agentID != nil }
    )
    if working { model.receive(SessionStateReport(state: .running, sessionID: session.id)) }
    return session
  }

  func contains(_ ref: String, in worktree: Worktree) async -> Bool {
    await git.succeeds(["merge-base", "--is-ancestor", ref, "HEAD"], in: worktree.path)
  }

  /// The one conflicts file written to the drops directory.
  func conflictsFile() throws -> String {
    let drops = root.appendingPathComponent("drops", isDirectory: true)
    let files = try #require(FileManager.default.enumerator(atPath: drops.path))
      .compactMap { $0 as? String }
      .filter { $0.hasSuffix(".md") && $0.contains("conflicts-") }
    let file = try #require(files.first)
    #expect(files.count == 1)
    return try String(contentsOf: drops.appendingPathComponent(file), encoding: .utf8)
  }
}
