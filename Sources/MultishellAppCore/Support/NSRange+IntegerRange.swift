import Foundation

extension NSRange {
  /// Unlike Foundation's failable `Range(_:)`, this never fails: an `NSNotFound`
  /// location is the caller's to rule out, as every caller here already does.
  public var integerRange: Range<Int> { location..<NSMaxRange(self) }
}
