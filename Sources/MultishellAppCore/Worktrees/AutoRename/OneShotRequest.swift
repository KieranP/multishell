import Foundation
import MultishellProcess

/// One run of an agent's CLI, handed to the model's runner whole so a test
/// sees what the agent would have been given.
struct OneShotRequest: Sendable {
  let executable: URL
  let arguments: [String]
  let directory: URL
  let environment: [String: String]
  let timeout: Duration
  /// What ends the run where its worktree is forgotten before the agent answers.
  let stopper: ProcessStopper
}
