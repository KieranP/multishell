/// How a run ended, and the branch it read, which the sidebar's listing may
/// have caught up with or moved past while the agent ran.
struct AutoRenameAnswer: Sendable {
  let branch: String?
  let outcome: Result<String, AutoRenameFailure>
}
