import Foundation
import Testing

@testable import MultishellAppCore
@testable import MultishellCore

@Suite @MainActor
struct AppModelEffectiveSettingsTests {
  @Test func ownSettingsReadTheStoredProjectAndNotTheCopyPassedIn() {
    let h = Harness()
    let stale = h.project
    var settings = stale.settings
    settings.autoStartAgent = true
    h.model.updateSettings(settings, for: stale)

    #expect(stale.settings.autoStartAgent == nil)
    #expect(h.model.ownSettings(of: stale).autoStartAgent == true)
  }

  /// `h.project` each time, not a copy taken once: these read the record the
  /// caller hands them, which every view resolves per render.
  @Test func theFileAnswersForAProjectThatLeftTheSettingAloneAndTheGlobalOtherwise() {
    let h = Harness()

    let global = h.model.inherited(.autoStartAgentOnCreate, global: true, for: h.project)
    #expect(global == InheritedSetting<Bool>(value: true, isFromRepository: false))

    h.model.applySharedSettingsReading(
      SharedSettingsReading(
        loaded: .success(SharedProjectSettings(autoStartAgentOnCreate: false)),
        modificationDate: .now, project: h.project),
      for: h.project)
    let file = h.model.inherited(.autoStartAgentOnCreate, global: true, for: h.project)
    #expect(
      file == InheritedSetting<Bool>(value: false, isFromRepository: true),
      "the value in force is the file's, and the form has to say so")

    let untouched = h.model.inherited(.opensTerminalOnCreate, global: true, for: h.project)
    #expect(
      untouched.isFromRepository == false, "a key the file does not carry is still the global")
  }

  /// `worktreeDirectory` says where a checkout lands, so it waits for the yes
  /// the hooks wait for. Until then the form names the global, not the file.
  @Test func theFilesWorktreeDirectoryIsNotInForceUntilItIsTrusted() {
    let h = Harness()
    h.model.setWorktreeDefaults(WorktreeSettings(worktreeDirectory: "/global/trees"))

    h.model.applySharedSettingsReading(
      SharedSettingsReading(
        loaded: .success(SharedProjectSettings(worktreeDirectory: ".worktrees")),
        modificationDate: .now, project: h.project),
      for: h.project)

    let directory = h.model.inherited(
      .worktreeDirectory, global: h.model.workspace.worktreeDefaults.worktreeDirectory,
      for: h.project)
    #expect(directory == InheritedSetting(value: "/global/trees", isFromRepository: false))
    #expect(
      h.model.effectiveWorktreeSettings(for: h.project).worktreeDirectory == "/global/trees",
      "and the path the sheet would use is the one the caption names")
  }

  @Test func theFilesWorktreeDirectoryIsInForceOnceTrusted() {
    let h = Harness()
    h.model.setWorktreeDefaults(WorktreeSettings(worktreeDirectory: "/global/trees"))
    h.model.applySharedSettingsReading(
      SharedSettingsReading(
        loaded: .success(SharedProjectSettings(worktreeDirectory: ".worktrees", digest: "file")),
        modificationDate: .now, project: h.project),
      for: h.project)

    h.model.setTrustsSharedSettings(true, for: h.project)

    let directory = h.model.inherited(
      .worktreeDirectory, global: h.model.workspace.worktreeDefaults.worktreeDirectory,
      for: h.project)
    #expect(directory == InheritedSetting(value: ".worktrees", isFromRepository: true))
    #expect(h.model.effectiveWorktreeSettings(for: h.project).worktreeDirectory == ".worktrees")
  }

  /// Blank is a value the file carries, not a key it left out, so the row
  /// shows it rather than falling back to the user's global.
  @Test func aBlankPrefixInTheFileIsTheValueInForceAndNotAFallThroughToTheGlobal() {
    let h = Harness()

    // A real global prefix, so the file's blank has something to beat.
    h.model.setWorktreeDefaults(WorktreeSettings(branchPrefix: "team/"))
    #expect(
      h.model.effectiveWorktreeSettings(for: h.project).qualifiedBranch("tabs") == "team/tabs")

    h.model.applySharedSettingsReading(
      SharedSettingsReading(
        loaded: .success(SharedProjectSettings(branchPrefix: "")), modificationDate: .now,
        project: h.project),
      for: h.project)

    let prefix = h.model.inherited(
      .branchPrefix, global: h.model.workspace.worktreeDefaults.branchPrefix, for: h.project)
    #expect(prefix == InheritedSetting(value: "", isFromRepository: true))
    #expect(
      h.model.effectiveWorktreeSettings(for: h.project).qualifiedBranch("tabs") == "tabs",
      "and the branch the sheet would create carries no prefix")
  }
}
