import Foundation
import MultishellCore
import MultishellGitKit

extension NewWorktreeDraft {
  /// The default button, naming the agent it starts. The custom command's
  /// own name is not a word to put on a button.
  public var createTitle: String {
    guard case .agent(let id, _)? = firstTab else { return t("sheet.create-worktree") }
    return id == AgentCatalogue.customID
      ? t("sheet.create-and-start-custom")
      : t("sheet.create-and-start", AgentCatalogue.displayName(id))
  }

  /// What the sheet says beside its spinner while a create runs, a hook
  /// taking a minute. `nil` is the tail: the refresh and the select.
  public static func progressText(for step: WorktreeCreationStep?) -> String {
    switch step {
    case .preCreateHook: t("step.pre-create-hook")
    case .addingWorktree: t("step.adding-worktree")
    case nil: t("step.creating-worktree")
    }
  }
}
