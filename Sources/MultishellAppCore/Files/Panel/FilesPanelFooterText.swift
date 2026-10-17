import MultishellCore
import MultishellGitKit

/// The Files panel footer's words: what changed, which the counts follow, then
/// what the panel left out, after them; see Docs/design/files.md.
public enum FilesPanelFooterText {
  public static func changes(_ summary: FilesPanelSummary) -> String {
    summary.changedFiles > 0
      ? t("files-panel.footer-modified", summary.changedFiles) : t("files-panel.no-modified")
  }

  /// `nil` where the panel lists everything.
  public static func omissions(_ summary: FilesPanelSummary) -> String? {
    var parts: [String] = []
    if summary.unlistedUntrackedFiles > 0 {
      parts.append(t("files-panel.unlisted-new", summary.unlistedUntrackedFiles))
    }
    if summary.isTrackedListCapped {
      parts.append(t("files-panel.tracked-capped", WorktreeGit.trackedPathLimit))
    }
    return parts.isEmpty ? nil : parts.joined(separator: " ")
  }
}
