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
      let accepted = await Self.gitAccepts(name, in: fixture.project.path)
      #expect(GitRefName.isValidBranch(name) == accepted, "\(name)")
    }
  }

  /// `check-ref-format --branch` is not the gate `git branch` is: it takes
  /// `HEAD` and `@` as shorthands for the current branch, where creating a
  /// branch is what these names are checked for. So the oracle is the real
  /// thing, in the fixture's own repository.
  private static func gitAccepts(_ name: String, in repository: URL) async -> Bool {
    let trimmed = name.trimmingCharacters(in: .whitespaces)
    guard !trimmed.isEmpty else { return false }
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
    process.currentDirectoryURL = repository
    process.arguments = ["git", "branch", "--", trimmed]
    process.standardOutput = FileHandle.nullDevice
    process.standardError = FileHandle.nullDevice
    do {
      try process.run()
    } catch {
      return false
    }
    process.waitUntilExit()
    guard process.terminationStatus == 0 else { return false }
    let cleanup = Process()
    cleanup.executableURL = URL(fileURLWithPath: "/usr/bin/env")
    cleanup.currentDirectoryURL = repository
    cleanup.arguments = ["git", "branch", "-D", "--", trimmed]
    cleanup.standardOutput = FileHandle.nullDevice
    cleanup.standardError = FileHandle.nullDevice
    try? cleanup.run()
    cleanup.waitUntilExit()
    return true
  }
}
