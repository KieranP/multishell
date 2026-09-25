import MultishellCore
import Testing

@testable import MultishellAppCore

/// The order carries the same sentence as a flag, so a caption cannot say
/// "on" about a picker or word the file differently from row to row.
extension InheritedSettingTests {
  @Test func theCaptionNamesTheLabelAndWhereItCameFrom() {
    let fromFile = InheritedSetting(
      value: WorktreeSortOrder.committedNewestFirst,
      isFromRepository: true)
    #expect(fromFile.caption == "Using the value in .multishell.json: Last commit, newest first.")

    let fromGlobal = InheritedSetting(
      value: WorktreeSortOrder.alphabetical,
      isFromRepository: false)
    #expect(fromGlobal.caption == "Using the global value: Name.")
  }
}
