import Foundation
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
}
