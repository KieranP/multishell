/// One thing up that waits on an answer, as `multishell info` lists it: what
/// stalls a script that cannot click, until `ui dismiss` takes it down.
struct PresentationEntry: Encodable, Equatable {
  enum Kind: String, Encodable {
    case alert
    case closeConfirmation = "close-confirmation"
    case actionRestart = "action-restart"
    case worktreeRemoval = "worktree-removal"
    case projectRemoval = "project-removal"
    case sharedSettingsTrust = "shared-settings-trust"
    case branchPublish = "branch-publish"
    case baseUpdate = "base-update"
    case updateAbort = "update-abort"
    case newWorktree = "new-worktree"
    case quickSwitcher = "quick-switcher"
    case tabRename = "tab-rename"
    case worktreeRename = "worktree-rename"
  }

  let kind: Kind
  /// An alert's words, `nil` for the rest.
  let title: String?
  let message: String?

  init(_ kind: Kind, title: String? = nil, message: String? = nil) {
    self.kind = kind
    self.title = title
    self.message = message
  }
}
