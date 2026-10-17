import AppKit
import MultishellAppCore

/// A row placed where its number says, not where TextKit 2 estimates; an
/// undocumented override point the drift tests guard. See files.md.
final class FixedRowLayoutFragment: NSTextLayoutFragment {
  /// Asked each time the frame is, not kept: replacing only a file's changed
  /// rows keeps the fragments below them, whose row numbers it moved.
  private weak var layoutDelegate: FixedRowLayoutDelegate?
  private let geometry: DiffRowGeometry

  override var layoutFragmentFrame: CGRect {
    let frame = super.layoutFragmentFrame
    let offset =
      textLayoutManager.map { manager in
        manager.offset(from: manager.documentRange.location, to: rangeInElement.location)
      } ?? 0
    let layoutDelegate = layoutDelegate
    let row = MainActor.assumeIsolated { layoutDelegate?.text.row(atOffset: offset) } ?? 0
    return CGRect(
      x: frame.minX,
      y: geometry.top(ofRow: row) - DiffRowGeometry.verticalInset,
      width: frame.width,
      height: geometry.rowHeight,
    )
  }

  init(
    textElement: NSTextElement,
    range: NSTextRange?,
    layoutDelegate: FixedRowLayoutDelegate,
    geometry: DiffRowGeometry,
  ) {
    self.layoutDelegate = layoutDelegate
    self.geometry = geometry
    super.init(textElement: textElement, range: range)
  }

  required init?(coder: NSCoder) { nil }
}
