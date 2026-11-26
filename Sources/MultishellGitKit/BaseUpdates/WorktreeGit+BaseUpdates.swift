import Foundation
import MultishellCore
import MultishellProcess

/// Merge from Base and Rebase onto Base, and the Abort that undoes one stopped
/// on conflicts; see Docs/design/worktrees/updating-from-base.md.
extension WorktreeGit {
  /// No editor opens where nobody can type into it: a hook asking for one gets
  /// the message git wrote.
  private static let writeEnvironment = ["GIT_EDITOR": "true"]

  private static func lockedOr(_ failure: ProcessFailure) -> any Error {
    IndexLocked.isNamed(in: failure.message) ? IndexLocked(message: failure.message) : failure
  }

  /// The base's remote fetched, the local copy of the trunk being often stale; no
  /// fetch for a local base. Throws `BaseRemoteMissing` where no listed remote holds it.
  public func fetch(_ base: DefaultBranch, into worktree: Worktree) async throws {
    guard base.isRemoteTracking else { return }
    guard let remote = try await remote(holding: base, in: worktree.path) else {
      throw BaseRemoteMissing(base: base.shortName)
    }
    _ = try await runner.run(
      ["fetch", "--prune", "--quiet", Self.endOfOptions, remote],
      in: worktree.path,
      environment: Self.networkEnvironment,
      timeout: Self.fetchTimeout,
    )
  }

  /// The merge or rebase onto the base as last fetched. Throws `IndexLocked` where
  /// the lock was taken before anything began, and git's failure otherwise.
  public func update(
    _ worktree: Worktree,
    from base: DefaultBranch,
    by method: UpdateMethod,
  ) async throws -> BaseUpdateOutcome {
    let startingPoint = await runner.output(
      ["rev-parse", "HEAD", base.fullName],
      in: worktree.path,
    )?
    .gitLines
    do {
      _ = try await runner.run(
        method.arguments(onto: base, from: worktree.name),
        in: worktree.path,
        environment: Self.writeEnvironment,
      )
      return .updated
    } catch let failure as ProcessFailure {
      // Another's stop, even of this kind begun just before, is not this update's to report.
      guard await unfinishedUpdate(in: worktree.path) == method,
        await isStop(by: method, from: startingPoint, in: worktree.path)
      else { throw Self.lockedOr(failure) }
      // Begun, a lock met partway or a hook rejecting the merge commit leaves nothing
      // unmerged: git's own words, as no retry can start it afresh.
      let paths = (try? await conflictedPaths(in: worktree)) ?? []
      guard paths.isEmpty else { return .unfinished(conflictedPaths: paths) }
      throw failure
    }
  }

  /// `git merge --abort` or `git rebase --abort`: the branch back where it was.
  public func abortUpdate(_ worktree: Worktree, method: UpdateMethod) async throws {
    do {
      _ = try await runner.run(method.abortArguments, in: worktree.path)
    } catch let failure as ProcessFailure {
      throw Self.lockedOr(failure)
    }
  }

  /// The merge or rebase stopped partway in the checkout, whoever started it.
  public func unfinishedUpdate(in checkout: URL) async -> UpdateMethod? {
    await runOnDispatch { UnfinishedOperationReading.unfinishedUpdate(inCheckout: checkout) }
  }

  /// What tells the stop in the checkout from a later one of its kind, `nil` for none.
  public func unfinishedUpdateMark(in checkout: URL) async -> String? {
    await runOnDispatch { UnfinishedOperationReading.unfinishedUpdateMark(inCheckout: checkout) }
  }

  /// The branch a rebase stopped in the checkout will put back, `nil` for none.
  public func branchBeingRebased(in checkout: URL) async -> String? {
    await runOnDispatch { UnfinishedOperationReading.branchBeingRebased(inCheckout: checkout) }
  }

  /// Whether the stop is the update's own, begun from `HEAD` and the base tip as read
  /// just before. Unread, any stop of its kind is taken as its own.
  private func isStop(
    by method: UpdateMethod,
    from startingPoint: [String]?,
    in checkout: URL,
  ) async -> Bool {
    guard let startingPoint, startingPoint.count == 2 else { return true }
    let (head, tip) = (startingPoint[0], startingPoint[1])
    switch method {
    case .merge:
      let mergeHead = await runOnDispatch {
        UnfinishedOperationReading.firstLine(of: "MERGE_HEAD", inCheckout: checkout)
      }
      let origHead = await pseudoRef("ORIG_HEAD", in: checkout)
      return mergeHead == tip && origHead == head

    case .rebase:
      return await runOnDispatch {
        UnfinishedOperationReading.isRebase(from: head, onto: tip, inCheckout: checkout)
      }
    }
  }

  /// A cherry-pick, revert or `git am` stopped partway in the checkout.
  public func isPickingCommits(in checkout: URL) async -> Bool {
    if await runOnDispatch({ UnfinishedOperationReading.isPickingFromAList(inCheckout: checkout) })
    {
      return true
    }
    for name in ["CHERRY_PICK_HEAD", "REVERT_HEAD"]
    where await pseudoRef(name, in: checkout) != nil {
      return true
    }
    return false
  }

  /// A pseudo-ref such as ORIG_HEAD: a file in the git directory, or, where git keeps
  /// refs in reftable, read through git; `show-ref --verify` takes no tag of the name.
  private func pseudoRef(_ name: String, in checkout: URL) async -> String? {
    let (line, isReftable) = await runOnDispatch {
      (
        UnfinishedOperationReading.firstLine(of: name, inCheckout: checkout),
        UnfinishedOperationReading.keepsRefsInReftable(inCheckout: checkout),
      )
    }
    guard line == nil, isReftable else { return line }
    let listed = await runner.output(["show-ref", "--verify", name], in: checkout)?.gitLines.first
    return listed?.split(separator: " ").first.map(String.init)
  }

  /// Each path git left unmerged, once: `ls-files` writes no index, as a
  /// `diff` refreshing stat data would.
  public func conflictedPaths(in worktree: Worktree) async throws -> [String] {
    let output = try await runner.run(["ls-files", "--unmerged", "-z"], in: worktree.path)
    return UnmergedPathParser.parse(output)
  }

  /// Each uncommitted change as status prints it, `M src/a.js` or `? notes.md`,
  /// for the refusal that names them.
  public func uncommittedChanges(in worktree: Worktree) async throws -> [String] {
    let output = try await runner.run(
      ["--no-optional-locks", "status", "--porcelain=v1", "-z", "--no-renames"],
      in: worktree.path,
    )
    return WorktreeStatusParser.parse(output).entries.map(\.uncommittedLine)
  }

  /// Whether a remote, a fork included, holds a branch of its name, which a rebase
  /// rewrites. A failed read counts as pushed: asking costs a click, a rewrite unasked more.
  public func isPushed(_ worktree: Worktree) async -> Bool {
    guard let branch = worktree.branch else { return false }
    guard let names = await runner.output(["remote"], in: worktree.path)?.gitLines else {
      return true
    }
    // Named in full per remote, as a name may hold a slash; git also lists what is below each.
    let candidates = names.map { RefName.remote("\($0)/\(branch)") }
    guard !candidates.isEmpty else { return false }
    let refs = await runner.output(
      ["for-each-ref", "--format=%(refname)"] + candidates,
      in: worktree.path,
    )
    return refs.map { !Set($0.gitLines).isDisjoint(with: candidates) } ?? true
  }

  /// The remote the base is a copy of, by the names git lists: one may hold a slash,
  /// so the ref alone cannot say where the name ends. `nil` where none does.
  private func remote(holding base: DefaultBranch, in checkout: URL) async throws -> String? {
    let names = try await runner.run(["remote"], in: checkout).gitLines
    return names.filter { base.fullName.hasPrefix(RefName.remotePrefix + $0 + "/") }
      .max { $0.count < $1.count }
  }
}
