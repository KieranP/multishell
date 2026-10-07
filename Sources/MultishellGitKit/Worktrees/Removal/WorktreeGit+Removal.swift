import Foundation
import MultishellCore

/// Taking a worktree's record out of git, and making sure first that the
/// directory at its path is still its checkout.
extension WorktreeGit {
  /// Forgets one record whose directory has already gone, a lock included.
  /// Only after the trash: with the directory there it would unlink it.
  func forget(_ worktree: Worktree, in project: Project) async throws {
    do {
      // One --force for a tree git cannot inspect, the second for a lock,
      // which stays on the record until this moment rather than being unlocked.
      _ = try await runner.run(
        ["worktree", "remove", "--force", "--force", worktree.path.path], in: project.path)
    } catch let refusal {
      // A record git cannot match to the path; see Docs/design/worktrees.md.
      do {
        _ = try await runner.run(["worktree", "prune"], in: project.path)
      } catch {
        throw WorktreeForgetFailure(path: worktree.path, underlying: error)
      }
      // prune exits 0 whether or not this record was one it took, and the
      // caller deletes the branch on a success; see Docs/design/worktrees.md.
      guard await !isListed(worktree.path, in: project) else {
        throw WorktreeForgetFailure(path: worktree.path, underlying: refusal)
      }
    }
  }

  /// Whether the directory at the record's path is still that worktree's
  /// checkout. Throws where the project's own git cannot answer.
  func isCheckout(of worktree: Worktree, in project: Project) async throws -> Bool {
    let common = try await commonGitDirectory(project)
    guard
      let output = await runner.output(
        ["rev-parse", Self.absolutePathsFlag, "--show-toplevel", "--git-common-dir"],
        in: worktree.path)
    else {
      // git refusing the directory, over ownership or a timeout, proves nothing
      // about whose it is; the `.git` file git wrote there does.
      return await runOnDispatch {
        guard let record = Self.recordDirectoryFromGitFile(in: worktree.path) else {
          return false
        }
        return Self.sameComparablePath(
          record.deletingLastPathComponent(), WorktreeRecords.worktreesDirectory(in: common))
      }
    }
    let lines = Self.absolutePaths(in: output, from: worktree.path)
    // The top level too: a plain directory inside the main checkout answers
    // with the main repository's common directory.
    return await runOnDispatch {
      lines.count == 2 && Self.sameComparablePath(lines[0], worktree.path)
        && Self.sameComparablePath(lines[1], common)
    }
  }

  /// A record whose path is now someone else's directory. That record alone
  /// goes, not every one prune would take; see worktrees.md.
  func forgetStale(_ worktree: Worktree, in project: Project) async throws {
    // A `.git` there is another repository's, which prune would keep too.
    let taken = await runOnDispatch {
      FileManager.default.fileExists(atPath: worktree.path.appendingPathComponent(".git").path)
    }
    guard !taken,
      let record = try await recordDirectory(whoseGitdirNames: worktree.path, in: project)
    else {
      throw WorktreePathTaken(path: worktree.path)
    }
    try await deleteDirectory(record)
    guard await !isListed(worktree.path, in: project) else {
      throw WorktreePathTaken(path: worktree.path)
    }
  }

  /// The directory under `<common>/worktrees` whose `gitdir` names `checkout`,
  /// absolute or, as `worktree.useRelativePaths` writes it, relative to itself.
  private func recordDirectory(
    whoseGitdirNames checkout: URL, in project: Project
  ) async throws -> URL? {
    let records = WorktreeRecords.worktreesDirectory(in: try await commonGitDirectory(project))
    return await runOnDispatch {
      let names =
        (try? FileManager.default.contentsOfDirectory(
          at: records, includingPropertiesForKeys: nil)) ?? []
      return names.first { record in
        guard
          let target = Self.directoryNamed(
            inFile: record.appendingPathComponent("gitdir"), relativeTo: record)
        else { return false }
        return Self.sameComparablePath(target.deletingLastPathComponent(), checkout)
      }
    }
  }

  /// `worktree remove` with no `--force`, which refuses a tree holding anything
  /// git would lose. Quiet: a path git does not list is simply refused.
  func removeUnchanged(_ path: URL, in project: Project) async {
    _ = try? await runner.run(["worktree", "remove", path.path], in: project.path)
  }
}
