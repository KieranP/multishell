import MultishellCore
import MultishellGitKit

/// What happened to a file, said the same of a panel row and a file tab.
extension AccessibilityText {
  static func statusChange(_ kind: StatusChange.Kind) -> String {
    switch kind {
    case .added: t("spoken.file-added")
    case .deleted: t("spoken.file-deleted")
    case .modified: t("spoken.file-modified")
    }
  }
}
