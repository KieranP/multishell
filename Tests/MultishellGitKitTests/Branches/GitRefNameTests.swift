import Foundation
import Testing

@testable import MultishellGitKit

/// Checked against real git rather than against the manual page: the point
/// of the table is that it agrees with `git check-ref-format`.
@Suite
struct GitRefNameTests {
  private static let names = [
    "feature", "feat/tabs", "release-1.2", "user/feat.x", "a_b-c", "ünïcode",
    "my branch", "foo..bar", "feat.lock", "has~tilde", "has^caret", "has:colon",
    "has?question", "has*star", "has[bracket", "back\\slash", "-leading", "trailing.",
    "@", "ref@{0}", ".hidden", "a//b", "nested/.hidden", "", "   ",
    "HEAD", "head", "Head", "x@", "@x", "refs/heads/x", "a.locket", "x/y.lock",
  ]

  @Test func everyNameAgreesWithWhatGitWillCreate() async throws {
    let fixture = try await RepositoryFixture.make()
    defer { fixture.tearDown() }
    for name in Self.names {
      let accepted = await Self.gitAccepts(name, in: fixture.project.path, using: fixture.git)
      #expect(GitRefName.isValidBranch(name) == accepted, "\(name)")
    }
  }

  /// `check-ref-format --branch` takes `HEAD` and `@` as shorthands for the current branch,
  /// so the oracle is `git branch` itself, in the fixture's own repository.
  private static func gitAccepts(
    _ name: String, in repository: URL, using git: GitRunner
  ) async -> Bool {
    let trimmed = name.trimmingCharacters(in: .whitespaces)
    guard !trimmed.isEmpty else { return false }
    guard await git.succeeds(["branch", "--", trimmed], in: repository) else { return false }
    _ = try? await git.run(["branch", "-D", "--", trimmed], in: repository)
    return true
  }
}
