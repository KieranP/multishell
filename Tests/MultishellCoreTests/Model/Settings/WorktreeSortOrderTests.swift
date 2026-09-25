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

  /// Raw values are what the state file holds, so they have to stay
  /// distinct from each other and stable against a case being reordered.
  @Test func everyOrderHasItsOwnStoredName() {
    let stored = WorktreeSortOrder.allCases.map(\.rawValue)
    #expect(Set(stored).count == stored.count)
    #expect(WorktreeSortOrder(rawValue: "alphabetical") == .alphabetical)
    #expect(WorktreeSortOrder.default == .alphabetical)
  }

  /// The raw values travel in a committed file, so a case renamed rather than added breaks it.
  @Test func theStoredNamesAreTheFileFormat() {
    #expect(
      WorktreeSortOrder.allCases.map(\.rawValue) == [
        "alphabetical", "createdNewestFirst", "createdOldestFirst", "committedNewestFirst",
        "committedOldestFirst",
      ])
  }
}
