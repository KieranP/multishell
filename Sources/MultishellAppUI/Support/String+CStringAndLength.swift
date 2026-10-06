import Foundation

extension String {
  /// For a C call that takes a pointer and a byte count. The count stops at
  /// the first NUL, as `strlen` does, so the two never disagree.
  func withCStringAndLength<Result>(
    _ body: (UnsafePointer<CChar>, UInt) throws -> Result
  ) rethrows -> Result {
    try withCString { try body($0, UInt(strlen($0))) }
  }
}
