import Foundation

@testable import MultishellAppCore
@testable import MultishellCore
@testable import MultishellGitKit

extension GitHarness {
  func commitFile(_ file: String, in worktree: Worktree) async throws {
    try await commitFile(file, holding: Data("\(file)\n".utf8), in: worktree)
  }

  func commitFile(_ file: String, holding data: Data, in worktree: Worktree) async throws {
    try data.write(to: worktree.path.appendingPathComponent(file))
    _ = try await git.run(["add", file], in: worktree.path)
    _ = try await git.run(["commit", "-q", "-m", file], in: worktree.path)
  }

  /// Another branch's work, then `head`'s squashed, off `main` and on no branch:
  /// what a trunk holds after the pull request at `head` is squash-merged.
  func squashOnSideBranch(of head: String) async throws -> String {
    _ = try await git.run(["checkout", "-q", "-b", "side", "main"], in: project.path)
    _ = try await git.run(["commit", "-q", "--allow-empty", "-m", "other"], in: project.path)
    _ = try await git.run(["checkout", "-q", head, "--", "."], in: project.path)
    _ = try await git.run(["commit", "-q", "-m", "squashed"], in: project.path)
    let tip = try await git.run(["rev-parse", "HEAD"], in: project.path)
      .trimmingCharacters(in: .whitespacesAndNewlines)
    _ = try await git.run(["checkout", "-q", "main"], in: project.path)
    _ = try await git.run(["branch", "-q", "-D", "side"], in: project.path)
    return tip
  }

  func tip(of worktree: Worktree) async throws -> String {
    try await git.run(["rev-parse", "HEAD"], in: worktree.path)
      .trimmingCharacters(in: .whitespacesAndNewlines)
  }

  func tip(ofBranch branch: String) async throws -> String {
    try await git.run(["rev-parse", branch], in: project.path)
      .trimmingCharacters(in: .whitespacesAndNewlines)
  }
}
