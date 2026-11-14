/// What a file tab's view carries its box across a re-read with, Unified or
/// Split holding a change by the same line, and the All changes tab by its file.
public protocol ChangeAnchoring {
  func anchor(ofChangeAt rows: Range<Int>) -> ChangeAnchor?
  func change(at anchor: ChangeAnchor) -> Range<Int>?
}
