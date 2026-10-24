import Foundation
import MultishellCore
import MultishellProcess

/// What a worktree changed since its branch left the project's base branch,
/// for the Files panel's Branch list and a file tab; see Docs/design/files.md.
extension WorktreeGit {
  /// Where `HEAD` and the base last shared a commit: `nil` where they share
  /// none, a branch with no commits included, and a throw where git cannot say.
  public func mergeBase(
    with base: DefaultBranch,
    inRepositoryAt path: URL,
  ) async throws
    -> String?
  {
    do {
      let output = try await runner.run(["merge-base", "HEAD", base.fullName], in: path)
      return output.trimmingCharacters(in: .whitespacesAndNewlines)
    } catch let failure as ProcessFailure where failure.status == 1 {
      // A shallow clone may only lack the ancestor past its cut, which is no verdict.
      let shallowCheck = ["rev-parse", "--is-shallow-repository"]
      guard await runner.output(shallowCheck, in: path)?.hasPrefix("false") == true else {
        throw failure
      }
      return nil
    } catch {
      // `--verify --quiet` exits 1 for an unborn `HEAD` alone; anything else says nothing.
      let headCheck = ["rev-parse", "--verify", "--quiet", "HEAD"]
      guard await runner.exitStatus(headCheck, in: path) == 1 else { throw error }
      return nil
    }
  }

  /// `diff-index` against the merge base reads the working tree, so a commit
  /// leaves a change listed. `nil` is a failed read, not a clean branch.
  public func branchChanges(
    inRepositoryAt path: URL,
    since base: DefaultBranch,
    status: WorktreeStatus?,
    diffAlgorithm: DiffAlgorithm,
  ) async -> BranchChanges? {
    let mergeBase: String?
    do {
      mergeBase = try await self.mergeBase(with: base, inRepositoryAt: path)
    } catch {
      return nil
    }
    guard let mergeBase else {
      return BranchChanges(baseName: base.shortName, mergeBase: nil, changes: [])
    }
    let arguments =
      ["--no-optional-locks", "diff-index", "--raw"] + Self.numstatOptions(diffAlgorithm)
    guard let output = await runner.output(arguments + [mergeBase], in: path) else { return nil }
    let tracked = RawNumstatParser.parse(output)
    // A file out of the index but on disk is the diff's deletion and status's new file.
    let listed = Set(tracked.filter { $0.kind != .deleted }.map(\.path))
    let changes = tracked + (await newFileChanges(in: path, from: status, besides: listed))
    return BranchChanges(
      baseName: base.shortName,
      mergeBase: mergeBase,
      changes: changes.sorted { $0.path < $1.path },
    )
  }

  /// The status read's own count of each new file where it made one, Staged
  /// Only making none; one added since that read is the diff's already.
  private func newFileChanges(
    in path: URL,
    from status: WorktreeStatus?,
    besides listed: Set<String>,
  ) async -> [StatusChange] {
    guard let status else { return [] }
    let paths = status.untrackedPaths.filter { !listed.contains($0) }
    // A path both removed from the index and on disk has two entries; the new file's is added.
    let added = status.changes.filter { $0.kind == .added }
    let counted = Dictionary(keepingFirst: added.map { ($0.path, $0) })
    let uncounted = paths.filter { counted[$0] == nil }
    return paths.compactMap { counted[$0] } + (await untrackedChanges(uncounted, in: path))
  }
}
