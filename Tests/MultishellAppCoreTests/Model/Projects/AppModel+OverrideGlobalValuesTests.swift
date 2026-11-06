import Foundation
import TestSupport
import Testing

@testable import MultishellAppCore
@testable import MultishellCore
@testable import MultishellGitKit

@Suite @MainActor
struct AppModelOverrideGlobalValuesTests {
  @Test func theFlagsColumnNamesTheGlobalLineOrNoneAndOpensAgentSettings() {
    let harness = Harness()
    harness.model.setPreferredAgent("claude")
    #expect(harness.model.globalAgentFlagsValue(for: harness.project).text == "none")

    harness.model.setAgentFlags("--verbose", for: "claude")

    let flags = harness.model.globalAgentFlagsValue(for: harness.project)
    #expect(flags.text == "--verbose")
    #expect(flags.settingsSection == .agentSettings)
  }

  @Test func theFlagsCellOpensNoPageWhileTheProjectRunsAnotherAgentThanTheGlobal() {
    let harness = Harness()
    harness.model.setPreferredAgent("claude")
    harness.model.setSettings(ProjectSettings(preferredAgentID: "codex"), for: harness.project)

    #expect(harness.model.globalAgentFlagsValue(for: harness.project).settingsSection == nil)
  }

  @Test func theFlagsCellOpensNoPageWithoutAGlobalAgentOrForACustomOne() {
    let harness = Harness()
    #expect(harness.model.globalAgentFlagsValue(for: harness.project).settingsSection == nil)

    harness.model.setPreferredAgent(AgentCatalogue.customID)

    #expect(harness.model.globalAgentFlagsValue(for: harness.project).settingsSection == nil)
  }

  @Test func theDefaultBranchColumnSaysSoWhenAScanDetectedNothing() {
    let harness = Harness()
    harness.model.defaultBranchScans[harness.project.id] = .absent

    #expect(harness.model.defaultBranchGlobalValue(for: harness.project).text == "Not detected")
  }

  @Test func theDefaultBranchColumnForgetsWhatWasDetectedOnceTheFolderIsGone() {
    let harness = Harness()
    harness.model.defaultBranchScans[harness.project.id] = .absent
    harness.model.detectedDefaultBranchNames[harness.project.id] = "main"

    harness.model.missingProjects.insert(harness.project.id)

    #expect(harness.model.defaultBranchGlobalValue(for: harness.project).text == "Not detected")
  }

  @Test func theDefaultBranchColumnDetectsNothingWithoutGitToScanWith() {
    let harness = Harness()

    #expect(harness.model.defaultBranchGlobalValue(for: harness.project).text == "Not detected")
  }

  @Test func theDefaultBranchColumnNamesTheRepositoryFilesBranchAndSaysItCameFromThere() {
    let harness = Harness()
    harness.model.applySharedSettingsReading(
      SharedSettingsReading(
        loaded: .success(SharedProjectSettings(defaultBranch: "release")),
        modificationDate: .now,
        project: harness.project,
      ),
      for: harness.project,
    )

    let branch = harness.model.defaultBranchGlobalValue(for: harness.project)

    #expect(branch.text == "release")
    #expect(branch.sourceNote != nil)
    #expect(branch.settingsSection == nil)
  }

  @Test func theShellAndAgentColumnsNameTheGlobalChoices() {
    let harness = Harness()
    harness.model.setPreferredAgent("claude")
    #expect(harness.model.globalAgentValue.text.hasPrefix("Claude Code"))
    #expect(harness.model.globalAgentValue.settingsSection == .agentSettings)
    #expect(harness.model.globalShellValue.settingsSection == .terminal)
  }

  @Test func theShellAndAgentColumnsReadAsTheirMenusDo() {
    let harness = Harness()
    let agentID = harness.model.globalAgentID
    let shellID = harness.model.globalShellID

    let agentMenu = harness.model.agentDetection.options(selected: agentID)
    let shellMenu = harness.model.shellDetection.options(selected: shellID)

    #expect(harness.model.globalAgentValue.text == agentMenu.first { $0.id == agentID }?.label)
    #expect(harness.model.globalShellValue.text == shellMenu.first { $0.id == shellID }?.label)
  }

  @Test func theDefaultBranchColumnSaysItWasDetectedAndOpensNoPage() {
    let harness = Harness()
    harness.model.defaultBranchScans[harness.project.id] = .found(
      .sample("trunk", remote: "origin")
    )
    harness.model.detectedDefaultBranchNames[harness.project.id] = "trunk"

    let branch = harness.model.defaultBranchGlobalValue(for: harness.project)
    #expect(branch.text == "Detected: trunk")
    #expect(branch.sourceNote == nil)
    #expect(branch.settingsSection == nil)
  }
}
