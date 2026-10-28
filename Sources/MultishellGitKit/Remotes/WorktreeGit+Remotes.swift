import Foundation
import MultishellCore
import MultishellProcess

extension WorktreeGit {
  private static let pushTimeout: Duration = .seconds(120)
  private static let lookupTimeout: Duration = .seconds(30)
  /// `ls-remote --exit-code`'s answer where nothing matched.
  private static let noMatchingRefStatus: Int32 = 2

  /// Every remote with its fetch URL. `nil` is a failed read, not no remotes.
  public func remotes(_ project: Project) async -> [GitRemote]? {
    await runner.output(["remote", "-v"], in: project.path).map(GitRemoteParser.parse)
  }

  /// The remote the branch's pushes go to by git's own config, its
  /// `pushRemote` or `remote.pushDefault`; `nil` where none names one.
  public func pushRemote(ofBranch branch: String, in directory: URL) async -> String? {
    // Not `%(push:remotename)`: it falls back to the remote the branch follows.
    if let named = await configValue("branch.\(branch).pushRemote", in: directory) {
      return named
    }
    return await configValue("remote.pushDefault", in: directory)
  }

  /// `git push` to `remoteBranch`, the upstream's own name where there is
  /// one. A network call, so no prompt and a timeout, as `fetch`.
  public func publish(
    _ branch: String,
    as remoteBranch: String,
    to remote: String,
    in directory: URL,
  ) async throws {
    let followed = await followedRemote(ofBranch: branch, in: directory)
    let pushedTo = await pushRemote(ofBranch: branch, in: directory)
    // A triangular setup, pushes named to go elsewhere than it follows, keeps
    // what it follows; anywhere else the scan finds the push by its upstream.
    let isTriangular =
      followed != nil && followed != "." && pushedTo != nil
      && pushedTo != followed
    let setsUpstream = !(isTriangular && pushedTo == remote)
    _ = try await runner.run(
      ["push", "--quiet"] + (setsUpstream ? ["--set-upstream"] : []) + [
        remote, "\(RefName.local(branch)):\(RefName.local(remoteBranch))",
      ],
      in: directory,
      environment: ["GIT_TERMINAL_PROMPT": "0"],
      timeout: Self.pushTimeout,
    )
  }

  /// Whether `remote` has `branch` now, which a remote-tracking ref only
  /// says as of the last fetch. `nil` where the remote could not be asked.
  public func remoteHasBranch(
    _ branch: String,
    on remote: String,
    in directory: URL,
  ) async -> Bool? {
    do {
      _ = try await runner.run(
        ["ls-remote", "--exit-code", "--heads", remote, RefName.local(branch)],
        in: directory,
        environment: ["GIT_TERMINAL_PROMPT": "0"],
        timeout: Self.lookupTimeout,
      )
      return true
    } catch let failure as ProcessFailure where failure.status == Self.noMatchingRefStatus {
      return false
    } catch {
      return nil
    }
  }

  private func followedRemote(ofBranch branch: String, in directory: URL) async -> String? {
    await configValue("branch.\(branch).remote", in: directory)
  }

  /// `nil` where the key is unset, as `git config --get` exits 1 for it.
  private func configValue(_ key: String, in directory: URL) async -> String? {
    let value = await runner.output(["config", "--get", key], in: directory)?
      .trimmingCharacters(in: .whitespacesAndNewlines)
    return value?.isEmpty == false ? value : nil
  }
}
