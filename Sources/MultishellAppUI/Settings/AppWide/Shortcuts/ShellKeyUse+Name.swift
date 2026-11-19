import MultishellAppCore

extension ShellKeyUse {
  /// Read mid-sentence: "the shell's history search".
  var name: String {
    switch self {
    case .startOfLine: t("shortcuts.shell-start-of-line")
    case .backOneCharacter: t("shortcuts.shell-back-one-character")
    case .endOfLine: t("shortcuts.shell-end-of-line")
    case .forwardOneCharacter: t("shortcuts.shell-forward-one-character")
    case .deleteToEndOfLine: t("shortcuts.shell-delete-to-end-of-line")
    case .clearScreen: t("shortcuts.shell-clear-screen")
    case .nextCommand: t("shortcuts.shell-next-command")
    case .previousCommand: t("shortcuts.shell-previous-command")
    case .historySearch: t("shortcuts.shell-history-search")
    case .swapCharacters: t("shortcuts.shell-swap-characters")
    case .deleteLine: t("shortcuts.shell-delete-line")
    case .deleteWord: t("shortcuts.shell-delete-word")
    case .pasteDeleted: t("shortcuts.shell-paste-deleted")
    }
  }
}
