import Foundation
import MultishellCore

/// Whether a checkout's populated submodules hold anything their remotes lack,
/// which removing the checkout's record would take; see worktrees/creating-and-removing.md.
extension WorktreeGit {
  /// Recursive: a nested submodule's repository lives in its parent's.
  func submodulesHoldWork(in checkout: URL) async throws -> Bool {
    for submodule in try await populatedSubmodules(in: checkout) {
      guard try await !holdsWork(submodule) else { return true }
    }
    return false
  }

  /// A change, an untracked file, or a commit on no remote, a stash's included.
  private func holdsWork(_ submodule: URL) async throws -> Bool {
    let status = try await runner.run(
      [
        "--no-optional-locks", "status", "--porcelain", "-z", "--untracked-files=normal",
        "--ignore-submodules=none",
      ],
      in: submodule,
    )
    guard status.isEmpty else { return true }
    let unpushed = try await runner.run(
      ["rev-list", "--count", "--all", "--not", "--remotes", "--"],
      in: submodule,
    )
    guard RevListCountParser.parse(unpushed) == 0 else { return true }
    return try await submodulesHoldWork(in: submodule)
  }

  /// Populated as git judges it: a `.git` in the submodule's folder.
  private func populatedSubmodules(in checkout: URL) async throws -> [URL] {
    let index = try await runner.run(
      ["--no-optional-locks", "ls-files", "-z", "--stage"],
      in: checkout,
    )
    let paths = index.split(separator: "\0").compactMap { entry -> Substring? in
      // The first tab ends the fields; a path may hold more.
      guard entry.hasPrefix(TrackedFileListParser.gitlinkMode + " ") else { return nil }
      return entry.split(separator: "\t", maxSplits: 1).last
    }
    return await runOnDispatch {
      paths.map { checkout.appending(path: String($0), directoryHint: .isDirectory) }
        .filter { $0.appendingPathComponent(".git").hasEntryOnDisk }
    }
  }
}
