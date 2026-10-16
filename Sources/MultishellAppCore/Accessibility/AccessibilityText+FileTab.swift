import MultishellCore

/// What a file tab's Changes rotor says of each changed line: its rows
/// carry no attribute a screen reader could tell an addition from.
extension AccessibilityText {
  /// "Removed, unstaged, was line 21: …", "Added, staged, line 40: …".
  public static func changedLine(_ line: DiffLine) -> String {
    let staging = line.isStaged ? t("spoken.staged") : t("spoken.unstaged")
    switch line.kind {
    case .added:
      return t("spoken.line-added", staging, line.newNumber ?? 0, line.text)

    case .context, .padding:
      return t("spoken.line", line.newNumber ?? 0, line.text)

    case .removed:
      return t("spoken.line-removed", staging, line.oldNumber ?? 0, line.text)
    }
  }
}
