import MultishellCore

/// What the detail area says with no worktree selected: where to click, or,
/// with no project yet, how to start.
public enum NoSelectionText {
  public static func title(hasProjects: Bool) -> String {
    hasProjects ? t("empty.select-worktree") : t("empty.add-project")
  }

  public static func caption(hasProjects: Bool) -> String {
    hasProjects ? t("empty.select-worktree-detail") : t("empty.add-project-detail")
  }
}
