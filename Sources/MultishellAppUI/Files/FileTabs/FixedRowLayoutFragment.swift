import AppKit
import MultishellAppCore

/// A row placed where its number says, not where TextKit 2 estimates; an
/// undocumented override point the drift tests guard. See files/file-tabs.md.
final class FixedRowLayoutFragment: NSTextLayoutFragment {
  /// Asked each time the frame is, not kept: a partial re-read and a review card's
  /// gap both move the rows below them while their fragments stay.
  private weak var layoutDelegate: FixedRowLayoutDelegate?
  private let rowHeight: CGFloat

  override var layoutFragmentFrame: CGRect {
    let frame = super.layoutFragmentFrame
    let offset =
      textLayoutManager.map { manager in
        manager.offset(from: manager.documentRange.location, to: rangeInElement.location)
      } ?? 0
    let layoutDelegate = layoutDelegate
    let top =
      MainActor.assumeIsolated {
        layoutDelegate.map { delegate in
          delegate.geometry.top(ofRow: delegate.displayText.row(atOffset: offset))
        }
      } ?? DiffRowGeometry.verticalInset
    return CGRect(
      x: frame.minX,
      y: top - DiffRowGeometry.verticalInset,
      width: frame.width,
      height: rowHeight,
    )
  }

  init(
    textElement: NSTextElement,
    range: NSTextRange?,
    layoutDelegate: FixedRowLayoutDelegate,
    rowHeight: CGFloat,
  ) {
    self.layoutDelegate = layoutDelegate
    self.rowHeight = rowHeight
    super.init(textElement: textElement, range: range)
  }

  required init?(coder: NSCoder) { nil }
}
