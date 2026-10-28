import MultishellCore

extension AccessibilityText {
  /// Whether a row or section that opens is open: one wording for every one.
  public static func disclosure(isExpanded: Bool) -> String {
    isExpanded ? t("spoken.expanded") : t("spoken.collapsed")
  }
}
