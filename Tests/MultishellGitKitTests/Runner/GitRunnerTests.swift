import Foundation
import MultishellCore
import TestScratch
import TestSupport
import Testing

@testable import MultishellGitKit

@Suite
struct GitRunnerTests {
  /// The fixtures turn signing off this way, and a machine that does not sign, CI included,
  /// never notices it breaking, so a plainly visible key is tested against the repo's own.
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
  /// is worded; see Docs/design/merged-branch.md.
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

  /// LFS, a credential helper or a diff driver has git exec a program off PATH, and from the
  /// Finder the app's PATH is the system directories alone.
  @Test func gitsOwnChildrenAreLookedUpOnTheLoginPath() async throws {
    let fixture = try await RepositoryFixture.make()
    defer { fixture.tearDown() }
    let bin = try Scratch.directory("gitpath")
    defer { Scratch.remove(bin) }
    try Scratch.script(
      "printf 'found the helper\\n'", at: bin.appendingPathComponent("ms-test-helper"))

    // An alias git runs through a shell, which is how a filter or credential
    // helper is reached: it is found only on the PATH the runner carries.
    let git = try TestGit.build(
      searchPath: bin.path + ":" + (ProcessInfo.processInfo.environment["PATH"] ?? ""),
      configuration: ["alias.helped": "!ms-test-helper"])
    let output = try await git.run(["helped"], in: fixture.project.path)
    #expect(output.contains("found the helper"))

    let blind = try TestGit.build(configuration: ["alias.helped": "!ms-test-helper"])
    await #expect(throws: (any Error).self) {
      try await blind.run(["helped"], in: fixture.project.path)
    }
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
    let status = try await WorktreeGit(runner: try GitRunner()).status(of: worktree)

    #expect(status.untracked == 1)
    #expect(status.isDirty, "the repository's own config said not to look")
    #expect(status.insertions == 1, "and its line is counted, the badge reading from the same list")
  }

  @Test func aRunnerGivenOnlyASearchPathRunsTheGitOnIt() async throws {
    let directory = try Scratch.directory("gitsearchpath")
    defer { Scratch.remove(directory) }
    try Scratch.script("echo the searched git", at: directory.appendingPathComponent("git"))
    let other = try Scratch.script(
      "echo the named git", at: directory.appendingPathComponent("other-git"))

    let searched = try await GitRunner(searchPath: directory.path).run(["--version"], in: directory)
    let named = try await GitRunner(executable: other, searchPath: directory.path)
      .run(["--version"], in: directory)

    #expect(searched.contains("the searched git"))
    #expect(named.contains("the named git"))
    #expect(throws: GitUnavailable.self) {
      _ = try GitRunner(searchPath: directory.appendingPathComponent("empty").path)
    }
  }

  /// From the Finder the process PATH is the system directories alone, so a
  /// git from a version manager is found only on the login shell's.
  @Test func gitIsLookedUpOnThePathItIsGiven() throws {
    let directory = try Scratch.directory("gitpath")
    defer { Scratch.remove(directory) }
    try Scratch.script("exit 0", at: directory.appendingPathComponent("git"))

    #expect(throws: Never.self) { _ = try WorktreeGit(searchPath: directory.path) }
    #expect(throws: GitUnavailable.self) {
      _ = try WorktreeGit(searchPath: directory.appendingPathComponent("empty").path)
    }
  }
}
