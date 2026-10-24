import MultishellCore

/// What a file tab's Changes rotor says of each changed line: its rows
/// carry no attribute a screen reader could tell an addition from.
extension AccessibilityText {
  /// "Removed, unstaged, was line 21: …", "Added, staged, line 40: …"; with
  /// no staging where the rows do not mark it, "Added, line 40: …".
  public static func changedLine(_ line: DiffLine, marksStaging: Bool) -> String {
    switch line.kind {
    case .added:
      return marksStaging
        ? t("spoken.line-added", staging(of: line), line.newNumber ?? 0, line.text)
        : t("spoken.line-added-unmarked", line.newNumber ?? 0, line.text)

    case .context, .padding:
      return t("spoken.line", line.newNumber ?? 0, line.text)

    case .removed:
      return marksStaging
        ? t("spoken.line-removed", staging(of: line), line.oldNumber ?? 0, line.text)
        : t("spoken.line-removed-unmarked", line.oldNumber ?? 0, line.text)
    }
  }

  private static func staging(of line: DiffLine) -> String {
    line.isStaged ? t("spoken.staged") : t("spoken.unstaged")
  }
}
