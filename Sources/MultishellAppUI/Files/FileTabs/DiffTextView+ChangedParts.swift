import AppKit
import MultishellAppCore

/// The words a changed line differs in, painted darker over its line's tint;
/// see Docs/design/files.md.
extension DiffTextView {
  func drawChangedParts(in rect: NSRect) {
    guard let layoutManager = textLayoutManager
    else { return }
    for row in geometry.rows(in: rect, count: displayText.lines.count) {
      let line = displayText.lines[row]
      guard !line.changedParts.isEmpty else { continue }
      (line.kind == .added ? partTints.added : partTints.removed).setFill()
      let start = displayText.rowStarts[row]
      for part in line.changedParts {
        fillTextSegments(of: part.shifted(by: start), layoutManager: layoutManager)
      }
    }
  }
}
