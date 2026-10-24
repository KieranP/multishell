import AppKit
import MultishellAppCore

/// Hands TextKit 2 a `FixedRowLayoutFragment` for each paragraph, which is one
/// row: lines never wrap, and the text holds one per line.
@MainActor
final class FixedRowLayoutDelegate: NSObject, @MainActor NSTextLayoutManagerDelegate {
  var displayText = DiffDisplayText.empty
  let geometry: DiffRowGeometry

  init(geometry: DiffRowGeometry) {
    self.geometry = geometry
  }

  /// An `NSTextView`'s layout runs on the main thread.
  func textLayoutManager(
    _ textLayoutManager: NSTextLayoutManager,
    textLayoutFragmentFor location: any NSTextLocation,
    in textElement: NSTextElement,
  ) -> NSTextLayoutFragment {
    FixedRowLayoutFragment(
      textElement: textElement,
      range: textElement.elementRange,
      layoutDelegate: self,
      geometry: geometry,
    )
  }
}
