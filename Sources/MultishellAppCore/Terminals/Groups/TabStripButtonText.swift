import MultishellCore

/// What a group's New Tab menu and split buttons say. The keystrokes act on
/// the focused group, so only that group's buttons name them.
public enum TabStripButtonText {
  public static var newTabLabel: String { t("tab.new") }

  /// Every item opens in this group; the focused one need not say so.
  public static func newTabHelp(isFocusedGroup: Bool) -> String {
    isFocusedGroup ? t("tab.new") : t("tab.new-in-group")
  }

  /// `keys` are the split's own, in force now; none drops the parenthesis.
  public static func splitHelp(
    _ axis: SplitAxis,
    isFocusedGroup: Bool,
    keys: KeyCombination?,
  ) -> String {
    let named = keys.map { t("shortcuts.in-parentheses", $0.glyphs) } ?? ""
    return switch (axis, isFocusedGroup) {
    case (.horizontal, true): t("tab.split-right-here", named)
    case (.horizontal, false): t("tab.split-right-in-group")
    case (.vertical, true): t("tab.split-down-here", named)
    case (.vertical, false): t("tab.split-down-in-group")
    }
  }

  /// The command whose keys a split button names.
  public static func splitCommand(_ axis: SplitAxis) -> ShortcutCommand {
    axis == .horizontal ? .splitRight : .splitDown
  }

  public static func splitLabel(_ axis: SplitAxis) -> String {
    axis == .horizontal ? t("tab.split-right") : t("tab.split-down")
  }
}
