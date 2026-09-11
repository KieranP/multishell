import Foundation
import MultishellCore
import TestScratch
import TestSupport
import Testing

@testable import MultishellGitKit

@Suite
struct GitRunnerConfigurationTests {
  /// The fixtures turn commit signing off this way, and nothing else would
  /// notice it stopping working: a machine whose global config does not sign
  /// commits, CI included, behaves the same either way. So the seam is
  /// tested on a key whose effect is plain to see, and against a repository
  /// whose own config says otherwise.
  @Test func aRunnersConfigurationBeatsTheRepositorysOwn() async throws {
    let fixture = try await RepositoryFixture.make()
    defer { fixture.tearDown() }
    let repository = fixture.project.path
    let git = try TestGit.build(configuration: ["user.name": "From the runner"])

    try "second\n".write(
      to: repository.appendingPathComponent("README.md"), atomically: true, encoding: .utf8)
    _ = try await git.run(["add", "."], in: repository)
    _ = try await git.run(["commit", "-q", "-m", "second"], in: repository)

    let author = try await git.run(["log", "-1", "--format=%an"], in: repository)
    #expect(author.trimmingCharacters(in: .whitespacesAndNewlines) == "From the runner")
    // The fixture's own runner passes no name, so the repository's answers.
    let first = try await fixture.git.run(["log", "-1", "--format=%an", "HEAD~1"], in: repository)
    #expect(first.trimmingCharacters(in: .whitespacesAndNewlines) == "Multishell Tests")
  }

  /// Config of the user's that changes what a read means rather than how it
  /// is worded; see docs/design/merged-branch.md.
  @Test func everyRunnerSilencesTheConfigThatWouldChangeWhatAReadMeans() async throws {
    let fixture = try await RepositoryFixture.make()
    defer { fixture.tearDown() }
    let git = try GitRunner()

    func value(_ key: String) async throws -> String {
      try await git.run(["config", "--get", key], in: fixture.project.path)
        .trimmingCharacters(in: .whitespacesAndNewlines)
    }
    #expect(try await value("log.showSignature") == "false")
    #expect(try await value("status.showUntrackedFiles") == "normal")

    let asked = try GitRunner(configuration: ["log.showSignature": "true"])
    let overridden = try await asked.run(
      ["config", "--get", "log.showSignature"], in: fixture.project.path)
    #expect(
      overridden.trimmingCharacters(in: .whitespacesAndNewlines) == "true",
      "a caller asking for it still wins")
  }

  /// A worktree holding nothing but untracked work read as clean, so the
  /// badge went over it and the removal dialog offered to trash it.
  @Test func aWorktreeWhoseWorkIsAllUntrackedReadsDirty() async throws {
    let fixture = try await RepositoryFixture.make()
    defer { fixture.tearDown() }
    let repository = fixture.project.path
    _ = try await fixture.git.run(["config", "status.showUntrackedFiles", "no"], in: repository)
    try "wip\n".write(
      to: repository.appendingPathComponent("scratch.txt"), atomically: true, encoding: .utf8)

    let worktree = Worktree(
      path: repository, projectID: fixture.project.id, head: "a", branch: "main")
    let status = try await WorktreeService(git: try GitRunner()).status(of: worktree)

    #expect(status.untracked == 1)
    #expect(status.isDirty, "the repository's own config said not to look")
  }

  /// From the Finder the process PATH is the system directories alone, so a
  /// git from a version manager is found only on the login shell's.
  @Test func gitIsLookedUpOnThePathItIsGiven() throws {
    let directory = try Scratch.directory("gitpath")
    defer { Scratch.remove(directory) }
    try Scratch.script("exit 0", at: directory.appendingPathComponent("git"))

    #expect(throws: Never.self) { _ = try WorktreeService(path: directory.path) }
    #expect(throws: GitUnavailable.self) {
      _ = try WorktreeService(path: directory.appendingPathComponent("empty").path)
    }
  }
}
