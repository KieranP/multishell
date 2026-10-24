import Foundation
import MultishellCore
import TestScratch
import TestSupport
import Testing

@testable import MultishellGitKit

/// The app watches `.git`, so a read that writes there raises the change
/// that schedules it again; see Docs/design/worktrees.md.
extension WorktreeGitTests {
  @Test func everyReadTheAppRunsByItselfLeavesGitsDirectoryAsItWas() async throws {
    let fixture = try await RepositoryFixture.make()
    defer { fixture.tearDown() }
    let project = fixture.project
    let git = WorktreeGit(runner: fixture.runner)
    try await fixture.commit("kept", file: "kept.txt", content: "kept\n")
    let side = try await fixture.addWorktree(onNewBranch: "side")
    try await fixture.commit("later", file: "later.txt", content: "later\n")
    try await TestRepository.commit(
      "side",
      files: ["side.txt": "side\n"],
      in: side,
      using: fixture.runner,
    )
    for tree in [project.path, side] {
      try Scratch.touch(tree.appendingPathComponent("kept.txt"))
      try "changed\n".write(
        to: tree.appendingPathComponent("README.md"),
        atomically: true,
        encoding: .utf8,
      )
      try "new\n".write(
        to: tree.appendingPathComponent("new.txt"),
        atomically: true,
        encoding: .utf8,
      )
    }
    try fixture.write("staged\n", to: "staged.txt")
    _ = try await fixture.runner.run(["add", "staged.txt"], in: project.path)
    let common = try await git.commonGitDirectory(project)
    let before = try DirectorySnapshot(of: common)

    #expect(await git.isRepository(side))
    #expect(await git.hasCommits(project))
    #expect(try await git.mainWorktreePath(containing: side).lastPathComponent == "demo")
    let worktrees = try await git.list(project)
    #expect(worktrees.count == 2)
    #expect(await git.isListed(side, in: project))
    #expect(await git.branchRefs(project)?.isEmpty == false)
    #expect(await git.branchNames(project)?.local.contains("side") == true)
    #expect(try await git.currentBranch(project) == "main")
    #expect(await git.lacksBranch("gone", in: project))
    #expect(await git.mergedBranches(into: "main", in: project) != nil)
    #expect(await git.hasWorkOfItsOwn("side", in: project) == true)
    #expect(await git.isPatchEquivalent("side", against: "main", in: project) == false)
    #expect(await git.isBehind("side", of: "main", in: project) == true)
    #expect(await git.changesAreOnBase("side", against: "main", in: project) == false)
    #expect(await git.ignoredPaths(["new.txt", "README.md"], in: project.path) == [])
    let base = try #require(
      DefaultBranch.resolve(from: await git.branchRefs(project) ?? [], override: nil)
    )
    for worktree in worktrees {
      #expect(
        await git.branchChanges(
          inRepositoryAt: worktree.path,
          since: base,
          status: try await git.status(of: worktree, counting: .stagedOnly),
          diffAlgorithm: .histogram,
        ) != nil
      )
      #expect(
        await git.patches(
          of: "README.md",
          in: worktree.path,
          diffAlgorithm: .histogram,
          since: base.tip,
        ) != nil
      )
      for indicator in GitStatusIndicator.allCases {
        #expect(try await git.status(of: worktree, counting: indicator).isDirty)
      }
      #expect(await git.trackedFiles(in: worktree.path)?.paths.contains("kept.txt") == true)
      #expect(await git.isRepositoryTop(worktree.path))
      #expect(await git.ignoredEntries(in: worktree.path) != nil)
      for path in ["kept.txt", "README.md", "new.txt"] {
        _ = try await git.committedSize(of: path, in: worktree.path)
        #expect(await git.patches(of: path, in: worktree.path, diffAlgorithm: .histogram) != nil)
      }
      #expect(
        await git.storedCopyStart(
          of: "README.md",
          in: worktree.path,
          byteCount: 8192,
          sizeLimit: 1 << 20,
        ) != nil
      )
    }

    #expect(try DirectorySnapshot(of: common) == before)
  }

  @Test func everyCountBeforeTheFirstCommitLeavesGitsDirectoryAsItWas() async throws {
    let fixture = try await RepositoryFixture.make(commit: false)
    defer { fixture.tearDown() }
    let git = WorktreeGit(runner: fixture.runner)
    let path = fixture.project.path
    try fixture.write("staged\n", to: "staged.txt")
    _ = try await fixture.runner.run(["add", "staged.txt"], in: path)
    try Scratch.touch(path.appendingPathComponent("staged.txt"))
    let common = try await git.commonGitDirectory(fixture.project)
    let before = try DirectorySnapshot(of: common)
    let main = try await fixture.worktree(onBranch: "main")

    for indicator in GitStatusIndicator.allCases {
      #expect(try await git.status(of: main, counting: indicator).insertions == 1)
    }

    #expect(try DirectorySnapshot(of: common) == before)
  }
}
