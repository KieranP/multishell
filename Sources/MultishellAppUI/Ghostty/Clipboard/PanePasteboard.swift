import AppKit
import MultishellAppCore

/// The general pasteboard as a pane pastes from it: copied files, then text
/// that is not blank, then images saved to files.
enum PanePasteboard {
  /// What NSTextView writes as the plain text of a selection that is only an
  /// attachment, an image among them.
  private static let attachmentPlaceholder: Character = "\u{FFFC}"

  @MainActor private static let pasteableTypes: [NSPasteboard.PasteboardType] =
    [.fileURL, .string] + PastedImageFile.pasteboardTypes

  /// Only the user's own paste saves an image or takes the session's wording;
  /// a program's read gets quoted paths. terminals.md says why.
  @MainActor
  static func pasteText(
    on pasteboard: NSPasteboard,
    dropsDirectory: URL,
    isUsersPaste: Bool,
    textForPastedFiles: ([URL]) -> String?,
  ) -> String? {
    let wording = isUsersPaste ? textForPastedFiles : quotedPaths
    let files = pasteboard.fileURLs
    guard files.isEmpty else { return wording(files) }
    let text = pasteboard.string(forType: .string)
    if let text, !isBlank(text) { return text }
    guard
      let images = PastedImageFile.files(for: pasteboard, in: dropsDirectory, saving: isUsersPaste)
    else { return text }
    guard let imageText = wording(images.urls) else {
      if images.isNew { DropCopies.remove(images.directory) }
      return nil
    }
    return imageText
  }

  private static func quotedPaths(_ files: [URL]) -> String? {
    FilePathText.pastedText(for: files, relativeTo: nil)
  }

  private static func isBlank(_ text: String) -> Bool {
    text.allSatisfy { $0.isWhitespace || $0 == attachmentPlaceholder }
  }

  /// Asked of the types alone, as menu validation runs too often to build the
  /// text; a file `pasteText` leaves out still counts.
  @MainActor
  static func hasPasteableType(on pasteboard: NSPasteboard) -> Bool {
    pasteboard.availableType(from: pasteableTypes) != nil
  }
}
