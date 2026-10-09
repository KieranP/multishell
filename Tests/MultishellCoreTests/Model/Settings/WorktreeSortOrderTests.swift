import Foundation
import Testing

@testable import MultishellCore

/// Both pickers are built off `allCases`, so two orders sharing a label, or
/// one added without one, give rows the user cannot tell apart.
@Suite
struct WorktreeSortOrderTests {
  @Test func everyOrderHasItsOwnLabel() {
    let labels = WorktreeSortOrder.allCases.map(\.displayName)
    #expect(Set(labels).count == labels.count, "two orders share a label")
    #expect(labels.allSatisfy { !$0.trimmingCharacters(in: .whitespaces).isEmpty })
  }

  @Test func theDefaultOrderIsAlphabetical() {
    #expect(WorktreeSortOrder.default == .alphabetical)
  }

  /// The raw values travel in a committed file, so a case renamed rather than added breaks it.
  @Test func theStoredNamesAreTheFileFormat() {
    #expect(
      WorktreeSortOrder.allCases.map(\.rawValue) == [
        "alphabetical", "createdNewestFirst", "createdOldestFirst", "committedNewestFirst",
        "committedOldestFirst",
      ]
    )
  }
}
