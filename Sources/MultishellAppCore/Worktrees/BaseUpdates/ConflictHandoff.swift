import Foundation
import MultishellCore

/// What Send Conflicts To writes for the agent, and the prompt a tab opened on
/// them starts with; see Docs/design/worktrees/updating-from-base.md.
enum ConflictHandoff {
  static func fileName(forWorktreeNamed name: String) -> String {
    AgentHandoff.fileName("conflicts", forWorktreeNamed: name)
  }

  /// The paths indented as code, every line of one, so a `#` or a newline in a
  /// path cannot start Markdown the agent reads as words to it.
  static func document(method: UpdateMethod, paths: [String]) -> String {
    let introduction =
      switch method {
      case .merge: t("conflicts.handoff-merge-introduction", method.agentContinueCommand)
      case .rebase: t("conflicts.handoff-rebase-introduction", method.agentContinueCommand)
      }
    let indented = paths.map { path in
      "    "
        + path.replacingOccurrences(of: "\r\n", with: "\n")
        .components(separatedBy: .newlines).joined(separator: "\n    ")
    }
    return introduction + "\n\n" + indented.joined(separator: "\n") + "\n"
  }

  /// A tab's first prompt, which has to say what to do on its own.
  static func prompt(mentioning file: String, method: UpdateMethod) -> String {
    t("conflicts.handoff-prompt", file, method.agentContinueCommand)
  }

  /// Around the path where the agent takes no mention; one alone says nothing.
  static func sentence(mentioning file: String) -> String {
    t("conflicts.handoff-sentence", file)
  }
}
