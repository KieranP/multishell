import MultishellCore
import MultishellGitKit

/// What a screen reader says of a Files panel row, which a hand-drawn list
/// cannot say itself: what it is, whether it is open, what changed.
extension AccessibilityText {
  public static func fileRow(_ row: FileTreeRow) -> String {
    var parts = [row.isFolder ? t("spoken.folder", row.name) : t("spoken.file", row.name)]
    if let folder = row.parentFolder { parts.append(t("spoken.in-folder", folder)) }
    if row.isFolder {
      parts.append(row.isExpanded ? t("spoken.expanded") : t("spoken.collapsed"))
      if row.showsChangeDot { parts.append(t("spoken.holds-changes")) }
    }
    if let kind = row.changeKind { parts.append(statusChange(kind)) }
    if let counts = row.lineCounts {
      if counts.showsInsertions { parts.append(t("spoken.lines-added", counts.insertions)) }
      if counts.showsDeletions { parts.append(t("spoken.lines-removed", counts.deletions)) }
    }
    return parts.joined(separator: ", ")
  }
}
