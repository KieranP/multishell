import MultishellCore

extension Worktree {
  /// What kind of worktree, the tooltip on the row's dot. `inSentence` is the
  /// same fact mid-sentence; see Docs/design/translation.md.
  public func kindText(inSentence: Bool = false) -> String {
    if isBare {
      return inSentence ? t("kind.bare-in-sentence") : t("kind.bare")
    }
    if isDetached {
      let shortHead = String(head.prefix(7))
      return inSentence
        ? t("kind.detached-in-sentence", shortHead) : t("kind.detached", shortHead)
    }
    if isPrimary {
      return inSentence ? t("kind.main-in-sentence") : t("kind.main")
    }
    return inSentence ? t("kind.linked-in-sentence") : t("kind.linked")
  }
}
