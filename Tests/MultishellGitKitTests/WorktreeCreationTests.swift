import Foundation
import MultishellCore
import MultishellProcess
import Testing

@testable import MultishellGitKit

/// The path most likely to lose someone's work if it is wrong.
@Suite(.serialized)
struct WorktreeCreationTests {
  @Test func theCreatedWorktreeIsWhereThePlannedPathSaid() async throws {
    let repo = try await RepositoryFixture.make()
    defer { repo.tearDown() }

    let planned = repo.coordinator.plannedPath(
      forBranch: "feat/tabs", in: repo.project, settings: repo.trees)
    let created = try await repo.coordinator.create(
      branch: "feat/tabs", in: repo.project, settings: repo.trees)

    #expect(created == planned)
    #expect(created.lastPathComponent == "feat-tabs", "slash becomes one directory")
    #expect(try await repo.branches() == ["feat/tabs", "main"], "the branch keeps its slash")
  }

  @Test func theNewBranchStartsAtTheRequestedBase() async throws {
    let repo = try await RepositoryFixture.make()
    defer { repo.tearDown() }
    let first = try await repo.head(of: repo.project.path)
    try await repo.commit("second", file: "b.txt", content: "b\n")
    _ = try await repo.git.run(["branch", "release", first], in: repo.project.path)

    let path = try await repo.coordinator.create(
      branch: "hotfix", basedOn: "release", in: repo.project, settings: repo.trees)

    #expect(try await repo.head(of: path) == first)
  }

  @Test func withoutABaseTheNewBranchStartsAtHEAD() async throws {
    let repo = try await RepositoryFixture.make()
    defer { repo.tearDown() }

    let path = try await repo.coordinator.create(
      branch: "x", in: repo.project, settings: repo.trees)

    #expect(try await repo.head(of: path) == repo.head(of: repo.project.path))
  }

  @Test func anExistingBranchIsCheckedOutNotRecreated() async throws {
    let repo = try await RepositoryFixture.make()
    defer { repo.tearDown() }
    _ = try await repo.git.run(["branch", "existing"], in: repo.project.path)

    let path = try await repo.coordinator.create(
      branch: "existing", createBranch: false, in: repo.project, settings: repo.trees)

    let onBranch = try await repo.git.run(["rev-parse", "--abbrev-ref", "HEAD"], in: path)
    #expect(onBranch.trimmingCharacters(in: .whitespacesAndNewlines) == "existing")
    #expect(try await repo.branches() == ["existing", "main"])
  }

  @Test func thePrefixIsAppliedAndNeverDoubled() async throws {
    let repo = try await RepositoryFixture.make()
    defer { repo.tearDown() }
    let settings = WorktreeSettings(worktreeDirectory: "../trees", branchPrefix: "k/")

    let a = try await repo.coordinator.create(branch: "one", in: repo.project, settings: settings)
    let b = try await repo.coordinator.create(branch: "k/two", in: repo.project, settings: settings)

    #expect(a.lastPathComponent == "k-one")
    #expect(b.lastPathComponent == "k-two")
    #expect(try await repo.branches() == ["k/one", "k/two", "main"])
  }

  @Test func thePrefixIsNotAppliedToAnExistingBranch() async throws {
    let repo = try await RepositoryFixture.make()
    defer { repo.tearDown() }
    _ = try await repo.git.run(["branch", "release"], in: repo.project.path)
    let settings = WorktreeSettings(worktreeDirectory: "../trees", branchPrefix: "k/")

    let planned = repo.coordinator.plannedPath(
      forBranch: "release", createBranch: false, in: repo.project, settings: settings)
    let path = try await repo.coordinator.create(
      branch: "release", createBranch: false, in: repo.project, settings: settings)

    #expect(path == planned)
    #expect(path.lastPathComponent == "release", "no k- in the directory either")
    let onBranch = try await repo.git.run(["rev-parse", "--abbrev-ref", "HEAD"], in: path)
    #expect(onBranch.trimmingCharacters(in: .whitespacesAndNewlines) == "release")
    #expect(try await repo.branches() == ["main", "release"], "nothing was created")
  }

  @Test func nestedContainersAreCreatedOnDemand() async throws {
    let repo = try await RepositoryFixture.make()
    defer { repo.tearDown() }
    let settings = WorktreeSettings(worktreeDirectory: "../deep/er/trees")

    let path = try await repo.coordinator.create(branch: "n", in: repo.project, settings: settings)

    #expect(path.path.hasSuffix("/deep/er/trees/n"))
    #expect(FileManager.default.fileExists(atPath: path.appendingPathComponent("README.md").path))
  }

  @Test func aBranchThatAlreadyExistsIsAGitErrorNotACrash() async throws {
    let repo = try await RepositoryFixture.make()
    defer { repo.tearDown() }
    _ = try await repo.git.run(["branch", "taken"], in: repo.project.path)

    await #expect(throws: ProcessFailure.self) {
      try await repo.coordinator.create(branch: "taken", in: repo.project, settings: repo.trees)
    }
    #expect(try await repo.coordinator.refresh(repo.project).count == 1, "nothing was created")
  }

  @Test func anOccupiedTargetDirectoryIsRefusedAndTheHookDoesNotRun() async throws {
    let repo = try await RepositoryFixture.make()
    defer { repo.tearDown() }
    var project = repo.project
    project.settings = ProjectSettings(
      postCreateHook: "touch \"$MULTISHELL_PROJECT_PATH/hook-ran\"")
    let target = repo.trees.worktreePath(forBranch: "busy", in: project)
    try FileManager.default.createDirectory(at: target, withIntermediateDirectories: true)
    try "x".write(to: target.appendingPathComponent("file"), atomically: true, encoding: .utf8)

    await #expect(throws: ProcessFailure.self) {
      try await repo.coordinator.create(branch: "busy", in: project, settings: repo.trees)
    }
    #expect(
      !FileManager.default.fileExists(atPath: project.path.appendingPathComponent("hook-ran").path))
  }

  @Test func aBranchCheckedOutElsewhereCannotBeCheckedOutAgain() async throws {
    let repo = try await RepositoryFixture.make()
    defer { repo.tearDown() }

    // `main` is checked out in the primary worktree already.
    await #expect(throws: ProcessFailure.self) {
      try await repo.coordinator.create(
        branch: "main", createBranch: false, in: repo.project, settings: repo.trees)
    }
  }

  @Test func removingKeepsTheBranch() async throws {
    let repo = try await RepositoryFixture.make()
    defer { repo.tearDown() }
    try await repo.coordinator.create(branch: "keep", in: repo.project, settings: repo.trees)
    let worktree = try #require(
      try await repo.coordinator.refresh(repo.project).first { $0.branch == "keep" })

    try await repo.coordinator.remove(worktree, in: repo.project)

    #expect(try await repo.branches() == ["keep", "main"])
    #expect(!FileManager.default.fileExists(atPath: worktree.path.path))
  }

  @Test func aDirtyWorktreeIsHandedToTheTrashNotRefused() async throws {
    let repo = try await RepositoryFixture.make()
    defer { repo.tearDown() }
    let path = try await repo.coordinator.create(
      branch: "dirty", in: repo.project, settings: repo.trees)
    try "uncommitted\n".write(
      to: path.appendingPathComponent("work.txt"), atomically: true, encoding: .utf8)
    let worktree = try #require(
      try await repo.coordinator.refresh(repo.project).first { $0.branch == "dirty" })
    let bin = repo.root.appendingPathComponent("bin", isDirectory: true)

    try await repo.coordinator.remove(
      worktree, in: repo.project,
      trash: { url in
        try FileManager.default.createDirectory(at: bin, withIntermediateDirectories: true)
        try FileManager.default.moveItem(at: url, to: bin.appendingPathComponent("dirty"))
      })

    #expect(!FileManager.default.fileExists(atPath: path.path))
    #expect(
      FileManager.default.fileExists(atPath: bin.appendingPathComponent("dirty/work.txt").path))
    #expect(try await repo.coordinator.refresh(repo.project).count == 1)
  }

  @Test func theListReflectsCreateAndRemove() async throws {
    let repo = try await RepositoryFixture.make()
    defer { repo.tearDown() }

    try await repo.coordinator.create(branch: "a", in: repo.project, settings: repo.trees)
    try await repo.coordinator.create(branch: "b", in: repo.project, settings: repo.trees)
    var listed = try await repo.coordinator.refresh(repo.project)
    #expect(listed.map(\.branch) == ["main", "a", "b"])
    #expect(listed[0].isPrimary && !listed[1].isPrimary)
    #expect(listed.allSatisfy { $0.projectID == repo.project.id })

    try await repo.coordinator.remove(listed[1], in: repo.project)
    listed = try await repo.coordinator.refresh(repo.project)
    #expect(listed.map(\.branch) == ["main", "b"])
  }

  @Test func statusesOmitWorktreesWhoseDirectoryIsGone() async throws {
    let repo = try await RepositoryFixture.make()
    defer { repo.tearDown() }
    let path = try await repo.coordinator.create(
      branch: "ghost", in: repo.project, settings: repo.trees)
    let worktrees = try await repo.coordinator.refresh(repo.project)
    try FileManager.default.removeItem(at: path)

    let statuses = await repo.coordinator.statuses(of: worktrees)

    #expect(statuses.keys.sorted() == [repo.project.id])
  }

  @Test func thePostDeleteHookRunsInTheRepositoryWithTheOldPath() async throws {
    let repo = try await RepositoryFixture.make()
    defer { repo.tearDown() }
    var project = repo.project
    project.settings = ProjectSettings(
      postDeleteHook: "printf \"%s|%s\" \"$PWD\" \"$MULTISHELL_WORKTREE_PATH\" > deleted.txt")
    let path = try await repo.coordinator.create(branch: "bye", in: project, settings: repo.trees)
    let worktree = try #require(
      try await repo.coordinator.refresh(project).first { $0.branch == "bye" })

    try await repo.coordinator.remove(worktree, in: project)

    let recorded = try String(
      contentsOf: project.path.appendingPathComponent("deleted.txt"), encoding: .utf8
    )
    .split(separator: "|").map(String.init)
    #expect(URL(fileURLWithPath: recorded[0]).standardizedFileURL.lastPathComponent == "demo")
    #expect(recorded[1] == path.path)
  }
}

@Suite(.serialized)
struct BranchQueryTests {
  @Test func currentAndLocalBranchesComeFromGit() async throws {
    let repo = try await RepositoryFixture.make()
    defer { repo.tearDown() }
    _ = try await repo.git.run(["branch", "feature"], in: repo.project.path)

    #expect(try await repo.coordinator.currentBranch(repo.project) == "main")
    #expect(try await repo.coordinator.localBranches(repo.project).sorted() == ["feature", "main"])
  }

  @Test func aRepositoryIsRecognisedAndItsParentIsNot() async throws {
    let repo = try await RepositoryFixture.make()
    defer { repo.tearDown() }
    #expect(await repo.coordinator.isRepository(repo.project.path))
    #expect(await repo.coordinator.isRepository(repo.root) == false)
  }
}
