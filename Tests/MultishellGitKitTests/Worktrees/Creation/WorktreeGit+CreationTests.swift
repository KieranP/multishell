import Foundation
import MultishellProcess
import TestSupport
import Testing

@testable import MultishellCore
@testable import MultishellGitKit

@Suite(.serialized)
struct WorktreeGitCreationTests {
  /// A developer's own `checkout.workers` would otherwise decide these tests.
  private static let realGitBlindToGlobalConfig =
    "GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1 exec git \"$@\""

  @Test func aNewIndexIsRefreshedOnceItsSecondHasPassed() async throws {
    let fake = try FakeGit.make("", loggingCalls: true)
    defer { fake.tearDown() }

    await WorktreeGit(runner: fake.runner).settleIndex(
      of: fake.directory,
      stopper: ProcessStopper(),
    )

    #expect(FakeGit.calls(in: fake.directory).contains { $0.contains("update-index") })
  }

  @Test func anAddChecksOutOnEveryCoreWhereTheUserSetNoWorkerCount() async throws {
    let workers = try await workersTheAddSees(userConfig: "exit 1")

    #expect(workers == "0")
  }

  @Test func anAddKeepsTheWorkerCountTheUserSet() async throws {
    let workers = try await workersTheAddSees(userConfig: "echo 1")

    #expect(workers.isEmpty)
  }

  @Test func aWorkerCountInTheRepositorysOwnConfigIsKept() async throws {
    let fixture = try await RepositoryFixture.make()
    defer { fixture.tearDown() }
    _ = try await fixture.runner.run(
      ["config", "checkout.workers", "3"],
      in: fixture.project.path,
    )

    let workers = try await workersTheAddSees(
      userConfig: Self.realGitBlindToGlobalConfig,
      in: fixture.project.path,
    )

    #expect(workers.isEmpty)
  }

  @Test func aRepositoryWithNoWorkerCountAnywhereChecksOutOnEveryCore() async throws {
    let fixture = try await RepositoryFixture.make()
    defer { fixture.tearDown() }

    let workers = try await workersTheAddSees(
      userConfig: Self.realGitBlindToGlobalConfig,
      in: fixture.project.path,
    )

    #expect(workers == "0")
  }

  @Test func aTreeAboveGitsParallelThresholdChecksOutWholeAndClean() async throws {
    let fixture = try await RepositoryFixture.make()
    defer { fixture.tearDown() }
    let repository = fixture.project.path
    var files: [String: String] = [:]
    for index in 0..<300 { files["src/dir\(index % 7)/file\(index).txt"] = "line \(index)\n" }
    try await TestRepository.commit("many", files: files, in: repository, using: fixture.runner)
    let script = repository.appending(path: "run.sh")
    try "#!/bin/sh\n".write(to: script, atomically: true, encoding: .utf8)
    try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: script.path)
    try FileManager.default.createSymbolicLink(
      atPath: repository.appending(path: "latest").path,
      withDestinationPath: "src/dir0/file0.txt",
    )
    _ = try await fixture.runner.run(["add", "."], in: repository)
    _ = try await fixture.runner.run(["commit", "-q", "-m", "script and link"], in: repository)
    let tree = repository.deletingLastPathComponent().appending(path: "parallel-tree")

    try await WorktreeGit(runner: fixture.runner).add(
      branch: "parallel",
      at: tree,
      basedOn: nil,
      createsBranch: true,
      tracksStartPoint: false,
      in: fixture.project,
      stopper: nil,
    )

    let status = try await fixture.runner.run(["status", "--porcelain"], in: tree)
    #expect(status.isEmpty)
    #expect(
      try String(contentsOf: tree.appending(path: "src/dir5/file299.txt"), encoding: .utf8)
        == "line 299\n"
    )
    let mode = try FileManager.default.attributesOfItem(atPath: tree.appending(path: "run.sh").path)
    #expect((mode[.posixPermissions] as? Int ?? 0) & 0o111 != 0)
    #expect(
      try FileManager.default.destinationOfSymbolicLink(atPath: tree.appending(path: "latest").path)
        == "src/dir0/file0.txt"
    )
  }

  /// The fake answers the user's config with `userConfig`, and at the add asks a
  /// real git what the environment alone sets, git's `command` scope.
  private func workersTheAddSees(
    userConfig: String,
    in project: URL? = nil,
  ) async throws -> String {
    let fake = try FakeGit.make(
      """
      case "$1" in
      config) \(userConfig) ;;
      worktree) git config --show-scope --get-all checkout.workers \
        | sed -n 's/^command\t//p' > "$SCRATCH/workers" ;;
      esac
      """
    )
    defer { fake.tearDown() }

    try await WorktreeGit(runner: fake.runner).add(
      branch: "feature",
      at: fake.directory.appending(path: "tree"),
      basedOn: nil,
      createsBranch: true,
      tracksStartPoint: false,
      in: Project(path: project ?? fake.directory),
      stopper: nil,
    )

    return try String(contentsOf: fake.directory.appending(path: "workers"), encoding: .utf8)
      .trimmingCharacters(in: .whitespacesAndNewlines)
  }

  @Test func anAlreadyStoppedStopperSkipsTheIndexRefresh() async throws {
    let fake = try FakeGit.make("", loggingCalls: true)
    defer { fake.tearDown() }
    let stopper = ProcessStopper()
    stopper.stop()

    await WorktreeGit(runner: fake.runner).settleIndex(of: fake.directory, stopper: stopper)

    #expect(!FakeGit.calls(in: fake.directory).contains { $0.contains("update-index") })
  }
}
