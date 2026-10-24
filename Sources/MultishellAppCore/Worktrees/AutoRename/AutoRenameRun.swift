import Foundation
import MultishellCore
import MultishellGitKit
import MultishellProcess

/// One Auto Rename off the main actor: read the branch, ask the agent, take
/// the name out of its reply. See Docs/design/agents.md.
struct AutoRenameRun: Sendable {
  /// A model on a slow day takes tens of seconds for a long diff; past this
  /// the user has stopped waiting for the row.
  private static let timeout: Duration = .seconds(90)

  /// Laid over the login shell's environment: the run's own hooks report to
  /// nothing, or the row's dot would move for a pane that is not there.
  private static let quietHooks = [
    SessionEnvironment.socketVariable: "/dev/null",
    SessionEnvironment.sessionVariable: "",
  ]

  /// Set by the shell the environment was captured from, in the home directory.
  private static let captureLocation: Set<String> = ["PWD", "OLDPWD", "_"]

  let worktree: Worktree
  let base: DefaultBranch
  let choice: AutoRenameChoice
  let executable: URL
  let loginVariables: [String: String]
  let stopper: ProcessStopper

  /// `nil` where the run was stopped before the agent started.
  func answer(
    using git: WorktreeGit,
    runner: @Sendable (OneShotRequest) async throws -> ProcessOutput,
  ) async -> AutoRenameAnswer? {
    let read: RenameMaterial?
    do {
      read = try await git.renameMaterial(inRepositoryAt: worktree.path, since: base)
    } catch {
      let failure = AutoRenameFailure.unreadableBranch(reason: PresentedError.describe(error))
      return AutoRenameAnswer(branch: worktree.branch, outcome: .failure(failure))
    }
    guard let material = read else {
      let failure = AutoRenameFailure.noSharedHistory(base: base.shortName)
      return AutoRenameAnswer(branch: worktree.branch, outcome: .failure(failure))
    }
    guard !material.isEmpty else {
      return AutoRenameAnswer(branch: material.branch, outcome: .failure(.nothingToName))
    }
    guard let outcome = await ask(about: material, runner: runner) else { return nil }
    return AutoRenameAnswer(branch: material.branch, outcome: outcome)
  }

  private func ask(
    about material: RenameMaterial,
    runner: @Sendable (OneShotRequest) async throws -> ProcessOutput,
  ) async -> Result<String, AutoRenameFailure>? {
    let agentName = choice.agent.name
    let prompt = AutoRenamePrompt.text(for: material)
    let request = OneShotRequest(
      executable: executable,
      arguments: choice.agent.oneShot.arguments(
        prompt: prompt,
        model: choice.model,
        effort: choice.effort,
      ),
      directory: worktree.path,
      environment: environment(),
      timeout: Self.timeout,
      stopper: stopper,
    )
    // Forgotten during the git reads: no answer is wanted, so none is asked for.
    guard !stopper.isStopRequested else { return nil }
    let output: ProcessOutput
    do {
      output = try await runner(request)
    } catch {
      return .failure(.couldNotStart(agent: agentName, reason: PresentedError.describe(error)))
    }
    if case .timedOut = output.stopReason {
      return .failure(.timedOut(agent: agentName, seconds: Int(Self.timeout.components.seconds)))
    }
    guard output.succeeded else {
      // Both, the error last: a warning on one would hide an error on the other.
      // Unstyled before the trim, here off the main actor, a styled tail trimming to nothing.
      let said = [output.standardError, output.standardOutput]
        .map { PrintableText.of($0).trimmingCharacters(in: .whitespacesAndNewlines) }
        .filter { !$0.isEmpty }
        .joined(separator: "\n")
      return .failure(.agentFailed(agent: agentName, status: output.status, said: said))
    }
    guard let name = AutoRenameReply.name(from: output.standardOutput) else {
      return .failure(.noName(agent: agentName))
    }
    return .success(name)
  }

  /// The login shell's, less where its capture ran: the agent starts in the
  /// worktree, and a CLI reading `PWD` finds it there.
  private func environment() -> [String: String] {
    loginVariables.filter { !Self.captureLocation.contains($0.key) }
      .merging(choice.agent.oneShot.environment) { $1 }
      .merging(Self.quietHooks) { $1 }
      .merging(["PWD": worktree.path.path]) { $1 }
  }
}
