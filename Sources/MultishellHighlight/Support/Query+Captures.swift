import Foundation
import MultishellAppCore
import SwiftTreeSitter

extension Query {
  /// Each capture meeting one of `ranges`, non-empty and in order, or every capture where `nil`,
  /// read as one cursor goes, since a cursor per range walks the tree again for each one.
  func captures(
    in tree: MutableTree,
    within ranges: [Range<Int>]?,
    matching context: SwiftTreeSitter.Predicate.Context,
  ) -> some Sequence<QueryCapture> {
    let cursor = execute(in: tree)
    if let first = ranges?.first, let last = ranges?.last {
      cursor.setRange(NSRange(first.lowerBound..<last.upperBound))
    }
    return cursor.resolve(with: context).lazy.flatMap(\.captures).filter { capture in
      ranges?.hasRange(meeting: capture.range.integerRange) ?? true
    }
  }
}
