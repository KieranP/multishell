import MultishellCore
import MultishellGitKit

/// The All changes tab's words: its bar's count, a fold's label, why a file
/// shows no rows, and each file's change letter.
public enum AllChangesText {
  public static func fileCount(_ count: Int) -> String {
    t("all-changes.file-count", count)
  }

  /// What the tab says with nothing to show, naming the base under Branch.
  public static func noChanges(sinceBase base: String?) -> String {
    base.map { t("files-panel.no-branch-changes", $0) } ?? t("all-changes.no-uncommitted")
  }

  public static func foldTitle(_ lines: ClosedRange<Int>) -> String {
    t("all-changes.show-unchanged", lines.count)
  }

  public static func foldLines(_ lines: ClosedRange<Int>) -> String {
    t("all-changes.fold-lines", lines.lowerBound, lines.upperBound)
  }

  public static func notice(_ notice: AllChangesNotice) -> String {
    switch notice {
    case .binary(let bytes): FileTabNoticeText.message(for: .binary(bytes: bytes)) ?? ""
    case .empty: t("all-changes.empty-file")
    case .image: t("all-changes.image")
    case .missing: FileTabNoticeText.message(for: .missing) ?? ""
    case .pastRowCap: t("all-changes.past-row-cap")
    case .reading: t("all-changes.reading")
    case .tooLarge(let bytes): FileTabNoticeText.message(for: .tooLarge(bytes: bytes)) ?? ""
    case .unreadable: FileTabNoticeText.message(for: .unreadable) ?? ""
    }
  }

  /// A file's own tab shows what this notice cannot: the image, or the rows past the cap.
  public static func offersFileTab(for notice: AllChangesNotice) -> Bool {
    notice == .image || notice == .pastRowCap
  }

  public static func letter(_ kind: StatusChange.Kind) -> String {
    switch kind {
    case .added: t("all-changes.letter-added")
    case .deleted: t("all-changes.letter-deleted")
    case .modified: t("all-changes.letter-modified")
    }
  }
}
