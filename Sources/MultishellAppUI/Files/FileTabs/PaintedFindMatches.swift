import AppKit
import MultishellAppCore

/// The find matches a file tab's text view last painted, shared by the unified
/// and split views so both move the selection by one rule.
@MainActor
final class PaintedFindMatches {
  private var shown: FindMatchesShown?
  private var hasPainted = false

  /// What the dropped view drew, so only a search or step since moves the selection.
  init(resuming shown: FileFindShown?) {
    self.shown = shown.map(FindMatchesShown.init)
  }

  /// Paints `find` where it or the text changed, answering what the model
  /// should keep, or nil where nothing was painted.
  func paint(
    _ find: FindMatchesShown,
    on textView: DiffTextView,
    textChanged: Bool,
    tint: NSColor,
  ) -> FileFindShown? {
    guard textChanged || shown != find else { return nil }
    let previous = shown
    shown = find
    textView.showFindMatches(find, after: previous, isFirstPaint: !hasPainted, tint: tint)
    hasPainted = true
    return find.shown
  }
}
