import MultishellCore

/// What a group's New Tab menu and split buttons say. The keystrokes act on
/// the focused group, so only that group's buttons name them.
public enum TabStripButtonText {
  /// Every item opens in this group; the focused one need not say so.
  public static func newTabHelp(isFocusedGroup: Bool) -> String {
    isFocusedGroup ? t("tab.new") : t("tab.new-in-group")
  }

  public static var newTabLabel: String { t("tab.new") }

  public static func splitHelp(_ axis: SplitAxis, isFocusedGroup: Bool) -> String {
    switch (axis, isFocusedGroup) {
    case (.horizontal, true): t("tab.split-right-here")
    case (.horizontal, false): t("tab.split-right-in-group")
    case (.vertical, true): t("tab.split-down-here")
    case (.vertical, false): t("tab.split-down-in-group")
    }
  }

  public static func splitLabel(_ axis: SplitAxis) -> String {
    axis == .horizontal ? t("tab.split-right") : t("tab.split-down")
  }
}
