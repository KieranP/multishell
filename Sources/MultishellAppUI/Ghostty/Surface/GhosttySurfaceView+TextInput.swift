import AppKit
import GhosttyKit

/// What input methods talk to, after Ghostty's own `NSTextInputClient`.
/// Composing text is drawn by libghostty as preedit, not by AppKit.
extension GhosttySurfaceView: @preconcurrency NSTextInputClient {
  func insertText(_ string: Any, replacementRange: NSRange) {
    guard NSApp.currentEvent != nil, let committed = Self.text(of: string) else { return }
    let text = surrogatePairing.text(for: committed as NSString)
    unmarkText()
    if textCommittedInKeyDown != nil {
      textCommittedInKeyDown?.append(text)
    } else if !text.isEmpty {
      // Dictation and the like arrive outside a key, typed rather than pasted.
      send(GhosttyKeyInput(committing: text))
    }
  }

  func setMarkedText(_ string: Any, selectedRange: NSRange, replacementRange: NSRange) {
    markedText = Self.text(of: string) ?? ""
    // Outside a key the input source changed mid-composition; show it now.
    if textCommittedInKeyDown == nil { syncPreedit() }
  }

  func unmarkText() {
    guard !markedText.isEmpty else { return }
    markedText = ""
    syncPreedit()
  }

  func hasMarkedText() -> Bool { !markedText.isEmpty }

  func markedRange() -> NSRange {
    markedText.isEmpty ? NSRange() : NSRange(location: 0, length: markedText.utf16.count)
  }

  func selectedRange() -> NSRange { NSRange() }

  func validAttributesForMarkedText() -> [NSAttributedString.Key] { [] }

  func attributedSubstring(
    forProposedRange range: NSRange, actualRange: NSRangePointer?
  ) -> NSAttributedString? {
    nil
  }

  func characterIndex(for point: NSPoint) -> Int { NSNotFound }

  /// Where the input method's candidate window goes: libghostty's cursor,
  /// whose y is the cell's bottom edge counted from the top.
  func firstRect(forCharacterRange range: NSRange, actualRange: NSRangePointer?) -> NSRect {
    guard let surface else { return .zero }
    var (x, y, width, height) = (0.0, 0.0, 0.0, 0.0)
    ghostty_surface_ime_point(surface, &x, &y, &width, &height)
    let size = ghostty_surface_size(surface)
    let cell = convertFromBacking(
      NSSize(width: Double(size.cell_width_px), height: Double(size.cell_height_px)))
    let placed = GhosttyInputMethodRect.rect(
      imePoint: CGRect(x: x, y: y, width: width, height: height), range: range, cell: cell)
    let rect = NSRect(
      x: placed.minX, y: bounds.height - placed.minY, width: placed.width, height: placed.height)
    guard let window else { return rect }
    return window.convertToScreen(convert(rect, to: nil))
  }

  func syncPreedit(clearingIfEmpty: Bool = true) {
    guard let surface else { return }
    if !markedText.isEmpty {
      markedText.withCStringAndLength { ghostty_surface_preedit(surface, $0, $1) }
    } else if clearingIfEmpty {
      ghostty_surface_preedit(surface, nil, 0)
    }
  }

  private static func text(of string: Any) -> String? {
    (string as? NSAttributedString)?.string ?? string as? String
  }
}
