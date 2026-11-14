import AppKit

/// A scroller's document laid out top down: a diff canvas's columns and gap
/// views, or the All changes list's files.
final class FlippedDocumentView: NSView {
  override var isFlipped: Bool { true }
}
