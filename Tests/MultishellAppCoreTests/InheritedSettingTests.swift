import Foundation
import MultishellCore
import Testing

@testable import MultishellAppCore

/// What a project settings form says about a flag the project leaves alone.
/// The global stopped being the only answer when the repository's file
/// gained these keys.
@Suite @MainActor
struct InheritedSettingTests {
  @Test func aFlagTheRepositorySuppliesIsNamedAsItsOwn() {
    let fromFile = InheritedFlag(value: true, isFromRepository: true)
    #expect(fromFile.caption == "Using the value in .multishell.json: on.")
    let fromGlobal = InheritedFlag(value: false, isFromRepository: false)
    #expect(fromGlobal.caption == "Using the global value: off.")
  }

  @Test func theFileAnswersForAProjectThatLeftTheSettingAloneAndTheGlobalOtherwise() {
    let h = Harness()
    let project = h.project

    let global = h.model.inherited(\.autoStartAgentOnCreate, global: true, for: project)
    #expect(global == InheritedFlag(value: true, isFromRepository: false))

    h.model.sharedSettings[project.id] = SharedProjectSettings(autoStartAgentOnCreate: false)
    let file = h.model.inherited(\.autoStartAgentOnCreate, global: true, for: project)
    #expect(
      file == InheritedFlag(value: false, isFromRepository: true),
      "the value in force is the file's, and the form has to say so")

    let untouched = h.model.inherited(\.opensTerminalOnCreate, global: true, for: project)
    #expect(
      untouched.isFromRepository == false, "a key the file does not carry is still the global")
  }
}

/// The order carries the same sentence as a flag, so a caption cannot say
/// "on" about a picker or word the file differently from row to row.
@Suite
struct InheritedOrderTests {
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
