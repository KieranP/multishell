/// How a branch takes in what has landed on its base: a merge commit, or its
/// own commits replayed on top. Also names one stopped partway, the app's or not.
public enum UpdateMethod: String, Codable, Hashable, Sendable {
  case merge
  case rebase

  /// What carries on once every conflict is resolved and added.
  public var continueCommand: String { "git \(rawValue) --continue" }

  /// The same for an agent: `--continue` opens the message's editor, which with no
  /// terminal waits for ever. `GIT_EDITOR` outranks `core.editor` and any exported one.
  public var agentContinueCommand: String { "env GIT_EDITOR=true git \(rawValue) --continue" }
}
