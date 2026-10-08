import Foundation
import Testing

@testable import MultishellAppCore
@testable import MultishellCore

@Suite @MainActor
struct AppModelProjectSettingsTests {
  @Test func ownSettingsReadTheStoredProjectAndNotTheCopyPassedIn() {
    let harness = Harness()
    let stale = harness.project
    var settings = stale.settings
    settings.autoStartsAgent = true
    harness.model.setSettings(settings, for: stale)

    #expect(stale.settings.autoStartsAgent == nil)
    #expect(harness.model.ownSettings(of: stale).autoStartsAgent == true)
  }

  /// `harness.project` each time, not a copy taken once: these read the record the
  /// caller hands them, which every view resolves per render.
  @Test func theFileAnswersForAProjectThatLeftTheSettingAloneAndTheGlobalOtherwise() {
    let harness = Harness()

    let global = harness.model.inherited(
      .autoStartsAgentOnCreate, global: true, for: harness.project)
    #expect(global == InheritedSetting<Bool>(value: true, isFromRepository: false))

    harness.model.applySharedSettingsReading(
      SharedSettingsReading(
        loaded: .success(SharedProjectSettings(autoStartsAgentOnCreate: false)),
        modificationDate: .now, project: harness.project),
      for: harness.project)
    let file = harness.model.inherited(.autoStartsAgentOnCreate, global: true, for: harness.project)
    #expect(
      file == InheritedSetting<Bool>(value: false, isFromRepository: true),
      "the value in force is the file's, and the form has to say so")

    let untouched = harness.model.inherited(
      .opensTerminalOnCreate, global: true, for: harness.project)
    #expect(
      untouched.isFromRepository == false, "a key the file does not carry is still the global")
  }

  /// `worktreeDirectory` says where a checkout lands, so it waits for the yes
  /// the hooks wait for. Until then the form names the global, not the file.
  @Test func theFilesWorktreeDirectoryIsNotInForceUntilItIsTrusted() {
    let harness = Harness()
    harness.model.setWorktreeDefaults(WorktreeSettings(worktreeDirectory: "/global/trees"))

    harness.model.applySharedSettingsReading(
      SharedSettingsReading(
        loaded: .success(SharedProjectSettings(worktreeDirectory: ".worktrees")),
        modificationDate: .now, project: harness.project),
      for: harness.project)

    let directory = harness.model.inherited(
      .worktreeDirectory, global: harness.model.workspace.worktreeDefaults.worktreeDirectory,
      for: harness.project)
    #expect(directory == InheritedSetting(value: "/global/trees", isFromRepository: false))
    #expect(
      harness.model.effectiveWorktreeSettings(for: harness.project).worktreeDirectory
        == "/global/trees",
      "and the path the sheet would use is the one the caption names")
  }

  @Test func theFilesWorktreeDirectoryIsInForceOnceTrusted() {
    let harness = Harness()
    harness.model.setWorktreeDefaults(WorktreeSettings(worktreeDirectory: "/global/trees"))
    harness.model.applySharedSettingsReading(
      SharedSettingsReading(
        loaded: .success(SharedProjectSettings(worktreeDirectory: ".worktrees", digest: "file")),
        modificationDate: .now, project: harness.project),
      for: harness.project)

    harness.model.setTrustsSharedSettings(true, for: harness.project)

    let directory = harness.model.inherited(
      .worktreeDirectory, global: harness.model.workspace.worktreeDefaults.worktreeDirectory,
      for: harness.project)
    #expect(directory == InheritedSetting(value: ".worktrees", isFromRepository: true))
    #expect(
      harness.model.effectiveWorktreeSettings(for: harness.project).worktreeDirectory
        == ".worktrees")
  }

  /// Blank is a value the file carries, not a key it left out, so the row
  /// shows it rather than falling back to the user's global.
  @Test func aBlankPrefixInTheFileIsTheValueInForceAndNotAFallThroughToTheGlobal() {
    let harness = Harness()

    // A real global prefix, so the file's blank has something to beat.
    harness.model.setWorktreeDefaults(WorktreeSettings(branchPrefix: "team/"))
    #expect(
      harness.model.effectiveWorktreeSettings(for: harness.project).qualifiedBranch("tabs")
        == "team/tabs")

    harness.model.applySharedSettingsReading(
      SharedSettingsReading(
        loaded: .success(SharedProjectSettings(branchPrefix: "")), modificationDate: .now,
        project: harness.project),
      for: harness.project)

    let prefix = harness.model.inherited(
      .branchPrefix, global: harness.model.workspace.worktreeDefaults.branchPrefix,
      for: harness.project)
    #expect(prefix == InheritedSetting(value: "", isFromRepository: true))
    #expect(
      harness.model.effectiveWorktreeSettings(for: harness.project).qualifiedBranch("tabs")
        == "tabs",
      "and the branch the sheet would create carries no prefix")
  }
}
