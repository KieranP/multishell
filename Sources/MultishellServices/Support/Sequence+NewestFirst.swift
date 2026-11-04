import Foundation

extension Sequence {
  /// Newest first by `date`, ties in the order given, as a host lists them.
  func newestFirst(by date: (Element) -> Date) -> [Element] {
    enumerated()
      .sorted { first, second in
        let firstDate = date(first.element)
        let secondDate = date(second.element)
        return firstDate == secondDate ? first.offset < second.offset : firstDate > secondDate
      }
      .map(\.element)
  }
}
