import Foundation

extension String {
  /// Contains `text`, both `foldedForMatching`, compared as UTF-8: over 200,000
  /// paths `contains` took 181 to 263 ms, a byte search 7 to 11 ms.
  func prefoldedContains(_ text: String) -> Bool {
    var searched = self
    var searchText = text
    return searched.withUTF8 { searched in
      searchText.withUTF8 { searchText in
        guard !searchText.isEmpty else { return true }
        guard searched.count >= searchText.count, let start = searched.baseAddress else {
          return false
        }
        return memmem(start, searched.count, searchText.baseAddress, searchText.count) != nil
      }
    }
  }
}
