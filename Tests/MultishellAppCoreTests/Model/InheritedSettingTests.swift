import Foundation
import MultishellCore
import Testing

@testable import MultishellAppCore

/// What a settings form says about a flag the project leaves alone. The
/// global stopped being the only answer when the file gained these keys.
@Suite @MainActor
struct InheritedSettingTests {
  @Test func aFlagTheRepositorySuppliesIsNamedAsItsOwn() {
    let fromFile = InheritedFlag(value: true, isFromRepository: true)
    #expect(fromFile.caption == "Using the value in .multishell.json: on.")
    let fromGlobal = InheritedFlag(value: false, isFromRepository: false)
    #expect(fromGlobal.caption == "Using the global value: off.")
  }

  /// `h.project` each time, not a copy taken once: these read the record the
  /// caller hands them, which every view resolves per render.
  @Test func theFileAnswersForAProjectThatLeftTheSettingAloneAndTheGlobalOtherwise() {
    let h = Harness()

    let global = h.model.inherited(\.autoStartAgentOnCreate, global: true, for: h.project)
    #expect(global == InheritedFlag(value: true, isFromRepository: false))

    h.model.noteSharedSettings(
      SharedSettingsReading(
        result: .success(SharedProjectSettings(autoStartAgentOnCreate: false)), stamp: .now,
        project: h.project),
      for: h.project)
    let file = h.model.inherited(\.autoStartAgentOnCreate, global: true, for: h.project)
    #expect(
      file == InheritedFlag(value: false, isFromRepository: true),
      "the value in force is the file's, and the form has to say so")

    let untouched = h.model.inherited(\.opensTerminalOnCreate, global: true, for: h.project)
    #expect(
      untouched.isFromRepository == false, "a key the file does not carry is still the global")
  }

  /// `worktreeDirectory` says where a checkout lands, so it waits for the yes
  /// the hooks wait for. Until then the form names the global, not the file.
  @Test func theFilesWorktreeDirectoryIsNotInForceUntilItIsTrusted() {
    let h = Harness()
    h.model.setWorktreeDefaults(WorktreeSettings(worktreeDirectory: "/global/trees"))

    h.model.noteSharedSettings(
      SharedSettingsReading(
        result: .success(SharedProjectSettings(worktreeDirectory: ".worktrees")), stamp: .now,
        project: h.project),
      for: h.project)

    let directory = h.model.inherited(
      \.worktreeDirectory, global: h.model.workspace.worktreeDefaults.worktreeDirectory,
      for: h.project)
    #expect(directory == InheritedSetting(value: "/global/trees", isFromRepository: false))
    #expect(
      h.model.worktreeSettings(for: h.project).worktreeDirectory == "/global/trees",
      "and the path the sheet would use is the one the caption names")
  }

  /// Blank is a value the file carries, not a key it left out, so the row
  /// shows it rather than falling back to the user's global.
  @Test func aBlankPrefixInTheFileIsTheValueInForceAndNotAFallThroughToTheGlobal() {
    let h = Harness()

    // A real global prefix, so the file's blank has something to beat.
    h.model.setWorktreeDefaults(WorktreeSettings(branchPrefix: "team/"))
    #expect(h.model.worktreeSettings(for: h.project).qualifiedBranch("tabs") == "team/tabs")

    h.model.noteSharedSettings(
      SharedSettingsReading(
        result: .success(SharedProjectSettings(branchPrefix: "")), stamp: .now, project: h.project),
      for: h.project)

    let prefix = h.model.inherited(
      \.branchPrefix, global: h.model.workspace.worktreeDefaults.branchPrefix, for: h.project)
    #expect(prefix == InheritedSetting(value: "", isFromRepository: true))
    #expect(
      h.model.worktreeSettings(for: h.project).qualifiedBranch("tabs") == "tabs",
      "and the branch the sheet would create carries no prefix")
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
