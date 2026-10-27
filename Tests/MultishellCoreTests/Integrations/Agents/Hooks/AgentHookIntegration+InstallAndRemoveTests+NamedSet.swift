import Foundation
import TestScratch
import Testing

@testable import MultishellCore

/// Antigravity's hook file, a file of the user's holding named sets of hooks.
extension AgentHookIntegrationInstallAndRemoveTests {
  private static let theirs = #"""
    {"guard":{"enabled":true,"PreToolUse":[{"matcher":"run_command","hooks":[{"type":"command","command":"check"}]}]}}
    """#

  @Test func antigravityGetsASetOfItsOwnBesideTheUsersAndRemoveTakesOnlyThatSet() throws {
    let (directory, file) = try scratchSettingsFile(named: "hooks.json")
    defer { Scratch.remove(directory) }
    try Self.theirs.write(to: file, atomically: true, encoding: .utf8)
    let antigravity = AgentHookCatalogue.antigravity

    try antigravity.install(into: file, helper: helper)
    let written = try AgentHookFile.read(file)
    #expect(Set(written.keys) == ["guard", "multishell"])
    let ours = try #require(written["multishell"] as? [String: Any])
    #expect(ours["enabled"] as? Bool == true)
    #expect(antigravity.hasOurHookUnderEveryEvent(in: file))
    #expect(antigravity.installState(in: file, helper: helper) == .current)

    try antigravity.remove(from: file)
    let left = try AgentHookFile.read(file)
    #expect(Set(left.keys) == ["guard"])
    let original = try #require(
      try JSONSerialization.jsonObject(with: Data(Self.theirs.utf8)) as? [String: Any]
    )
    #expect(AgentHookFile.render(left) == AgentHookFile.render(original))
  }

  @Test func updatingAntigravitysSetKeepsItSwitchedOffWhereTheUserSwitchedItOff() throws {
    let (directory, file) = try scratchSettingsFile(named: "hooks.json")
    defer { Scratch.remove(directory) }
    let antigravity = AgentHookCatalogue.antigravity
    try antigravity.install(into: file, helper: helper)
    var settings = try AgentHookFile.read(file)
    var set = try #require(settings["multishell"] as? [String: Any])
    set["enabled"] = false
    settings["multishell"] = set
    try AgentHookFile.write(settings, to: file)

    try antigravity.install(into: file, helper: helper)
    let updated = try #require(try AgentHookFile.read(file)["multishell"] as? [String: Any])
    #expect(updated["enabled"] as? Bool == false)
  }

  @Test func aRefusalNamesTheSetItCouldNotReadNotHooks() throws {
    let (directory, file) = try scratchSettingsFile(named: "hooks.json")
    defer { Scratch.remove(directory) }
    try #"{"multishell":{"Stop":"x"}}"#.write(to: file, atomically: true, encoding: .utf8)

    let error = #expect(throws: UnexpectedHookEntriesShape.self) {
      try AgentHookCatalogue.antigravity.install(into: file, helper: helper)
    }
    #expect(error?.section == "multishell")
    #expect(error?.event == "Stop")
  }

  @Test func updatingASetWhoseSwitchIsNullSwitchesItOn() throws {
    let (directory, file) = try scratchSettingsFile(named: "hooks.json")
    defer { Scratch.remove(directory) }
    try #"{"multishell":{"enabled":null}}"#.write(to: file, atomically: true, encoding: .utf8)

    try AgentHookCatalogue.antigravity.install(into: file, helper: helper)
    let set = try #require(try AgentHookFile.read(file)["multishell"] as? [String: Any])
    #expect(set["enabled"] as? Bool == true)
  }
}
