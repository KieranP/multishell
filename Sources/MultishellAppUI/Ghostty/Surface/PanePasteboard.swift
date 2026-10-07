import AppKit
import MultishellAppCore

/// The general pasteboard as a pane pastes from it: copied files as their
/// paths, else the text.
enum PanePasteboard {
  /// What a paste types: copied files as a drop types them, or else the text.
  /// Files all left out type nothing, Finder's text being their names.
  @MainActor
  static func pasteText(on pasteboard: NSPasteboard = .general) -> String? {
    let files = pasteboard.fileURLs
    guard files.isEmpty else { return FilePathText.pastedText(for: files) }
    return pasteboard.string(forType: .string)
  }

  /// Asked of the types alone, as menu validation runs too often to build the
  /// text; a file `pasteText(on:)` leaves out still counts.
  @MainActor
  static func hasPasteableType(on pasteboard: NSPasteboard = .general) -> Bool {
    pasteboard.availableType(from: [.fileURL, .string]) != nil
  }
}
