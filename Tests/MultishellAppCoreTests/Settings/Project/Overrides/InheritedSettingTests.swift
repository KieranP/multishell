import Testing

@testable import MultishellAppCore
@testable import MultishellCore

/// What a project's settings table shows for a setting the project leaves
/// alone. The global stopped being the only answer when the file gained these keys.
@Suite
struct InheritedSettingTests {
  @Test func aFlagTheRepositorySuppliesIsNamedAsItsOwnAndOpensNoPage() {
    let fromFile = InheritedSetting<Bool>(value: true, isFromRepository: true)
    #expect(fromFile.globalValue(setIn: .terminal).text == "On")
    #expect(fromFile.globalValue(setIn: .terminal).sourceNote == "From .multishell.json")
    #expect(fromFile.globalValue(setIn: .terminal).settingsSection == nil)

    let fromGlobal = InheritedSetting<Bool>(value: false, isFromRepository: false)
    #expect(fromGlobal.globalValue(setIn: .terminal).text == "Off")
    #expect(fromGlobal.globalValue(setIn: .terminal).sourceNote == nil)
    #expect(fromGlobal.globalValue(setIn: .terminal).settingsSection == .terminal)
  }

  @Test func aSortOrderShowsItsPickerLabelAndOpensNoPageTheSidebarMenuSettingIt() {
    let fromGlobal = InheritedSetting(
      value: WorktreeSortOrder.committedNewestFirst,
      isFromRepository: false,
    )
    #expect(fromGlobal.globalValue.text == "Last commit, newest first")
    #expect(fromGlobal.globalValue.settingsSection == nil)
  }

  @Test func aBlankPrefixReadsAsNoneAndABlankDirectoryAsTheDefault() {
    let blank = InheritedSetting(value: "", isFromRepository: false)
    #expect(blank.prefixGlobalValue.text == "none")
    #expect(blank.directoryGlobalValue.text == "default")
    #expect(blank.directoryGlobalValue.settingsSection == .worktrees)
  }
}
