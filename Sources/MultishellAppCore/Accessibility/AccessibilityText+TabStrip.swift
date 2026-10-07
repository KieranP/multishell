import MultishellCore

extension AccessibilityText {
  /// A tab in the strip: its title, the agent its mark names, whether it is
  /// the one shown, its state and whether it is split.
  public static func tab(
    title: String, isShown: Bool, isSplit: Bool, state: SessionState?, agentName: String?
  )
    -> String
  {
    var parts = [t("spoken.tab", title)]
    parts.append(contentsOf: spokenAgent(agentName, title: title))
    if isShown { parts.append(t("spoken.selected")) }
    if isSplit { parts.append(t("spoken.split")) }
    if let state { parts.append(state.displayName) }
    return parts.joined(separator: ", ")
  }

  /// One group of tabs, said before its tabs are. Empty for a worktree with
  /// one group, "group 1 of 1" before every tab being noise.
  public static func tabGroup(position: Int, of count: Int, isFocused: Bool) -> String {
    guard count > 1 else { return "" }
    var text = t("spoken.tab-group", position, count)
    if isFocused { text += ", " + t("spoken.focused") }
    return text
  }

  /// The band down the edge of a group's terminal area, which a dragged
  /// tab lands on to get a group of its own.
  public static func newTabGroupBand(_ placement: TerminalTab.Placement) -> String {
    placement == .before
      ? t("spoken.new-tab-group-left") : t("spoken.new-tab-group-right")
  }
}
