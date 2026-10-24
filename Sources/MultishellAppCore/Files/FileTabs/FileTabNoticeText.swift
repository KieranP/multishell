import Foundation
import MultishellCore

/// What a file tab says in place of rows, and whether its editor is offered:
/// a file that is nowhere has nothing to open.
public enum FileTabNoticeText {
  /// `nil` for text, which shows rows instead.
  public static func message(for content: FileTabContent) -> String? {
    switch content {
    case .binary(let bytes): t("file.binary-notice", size(bytes))
    case .missing: t("file.missing-notice")
    case .released, .releasedFollowingStatus, .text: nil
    case .tooLarge(let bytes): t("file.too-large-notice", size(bytes))
    case .unreadable: t("file.unreadable-notice")
    }
  }

  public static func offersEditor(for content: FileTabContent) -> Bool { content != .missing }

  private static func size(_ bytes: Int) -> String {
    ByteCountFormatter.string(fromByteCount: Int64(bytes), countStyle: .file)
  }
}
