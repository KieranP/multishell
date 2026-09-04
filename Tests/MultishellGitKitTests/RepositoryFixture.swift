import Foundation
import MultishellCore

@testable import MultishellGitKit

/// A throwaway repository under the temp directory, removed on `tearDown`.
struct RepositoryFixture {
  let git: GitRunner
  let root: URL
  let project: Project

  static func make(commit: Bool = true) async throws -> RepositoryFixture {
    let git = try GitRunner()
    let root = URL(fileURLWithPath: NSTemporaryDirectory())
      .appendingPathComponent("multishell-tests-\(UUID().uuidString)", isDirectory: true)
    let repository = root.appendingPathComponent("demo", isDirectory: true)
    try FileManager.default.createDirectory(at: repository, withIntermediateDirectories: true)
    _ = try await git.run(["init", "--initial-branch=main"], in: repository)
    _ = try await git.run(["config", "user.email", "tests@multishell.local"], in: repository)
    _ = try await git.run(["config", "user.name", "Multishell Tests"], in: repository)
    let fixture = RepositoryFixture(git: git, root: root, project: Project(path: repository))
    if commit { try await fixture.commit("initial", file: "README.md", content: "hello\n") }
    return fixture
  }

  func commit(_ message: String, file: String, content: String) async throws {
    try content.write(
      to: project.path.appendingPathComponent(file), atomically: true, encoding: .utf8)
    _ = try await git.run(["add", "."], in: project.path)
    _ = try await git.run(["commit", "-q", "-m", message], in: project.path)
  }

  func head(of directory: URL) async throws -> String {
    try await git.run(["rev-parse", "HEAD"], in: directory).trimmingCharacters(
      in: .whitespacesAndNewlines)
  }

  func branches() async throws -> [String] {
    try await git.run(
      ["for-each-ref", "--format=%(refname:short)", "refs/heads"], in: project.path
    )
    .split(whereSeparator: \.isNewline).map(String.init).sorted()
  }

  var coordinator: WorktreeCoordinator { WorktreeCoordinator(service: WorktreeService(git: git)) }
  var trees: WorktreeSettings { WorktreeSettings(worktreeDirectory: "../trees") }

  func tearDown() {
    try? FileManager.default.removeItem(at: root)
  }
}
