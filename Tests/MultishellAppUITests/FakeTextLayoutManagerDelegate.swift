import AppKit

@testable import MultishellAppUI

/// Stands in for a text view's layout delegate, counting the rows TextKit lays out.
@MainActor
final class FakeTextLayoutManagerDelegate: NSObject, @MainActor NSTextLayoutManagerDelegate {
  private(set) var rowsMade = 0
  private let wrapped: FixedRowLayoutDelegate

  init(wrapping wrapped: FixedRowLayoutDelegate) {
    self.wrapped = wrapped
  }

  func textLayoutManager(
    _ textLayoutManager: NSTextLayoutManager,
    textLayoutFragmentFor location: any NSTextLocation,
    in textElement: NSTextElement,
  ) -> NSTextLayoutFragment {
    rowsMade += 1
    return wrapped.textLayoutManager(
      textLayoutManager,
      textLayoutFragmentFor: location,
      in: textElement,
    )
  }
}
