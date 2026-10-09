import Testing

@testable import MultishellAppCore
@testable import MultishellCore

/// What a settings form says about a flag the project leaves alone. The
/// global stopped being the only answer when the file gained these keys.
@Suite
struct InheritedSettingTests {
  @Test func aFlagTheRepositorySuppliesIsNamedAsItsOwn() {
    let fromFile = InheritedSetting<Bool>(value: true, isFromRepository: true)
    #expect(fromFile.caption == "Using the value in .multishell.json: on.")
    let fromGlobal = InheritedSetting<Bool>(value: false, isFromRepository: false)
    #expect(fromGlobal.caption == "Using the global value: off.")
  }

  /// The order carries the same sentence as a flag, so a caption cannot say
  /// "on" about a picker or word the file differently from row to row.
  @Test func aSortOrderCaptionNamesItsLabelAndWhereItCameFrom() {
    let fromFile = InheritedSetting(
      value: WorktreeSortOrder.committedNewestFirst,
      isFromRepository: true,
    )
    #expect(fromFile.caption == "Using the value in .multishell.json: Last commit, newest first.")

    let fromGlobal = InheritedSetting(
      value: WorktreeSortOrder.alphabetical,
      isFromRepository: false,
    )
    #expect(fromGlobal.caption == "Using the global value: Name.")
  }
}
