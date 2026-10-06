import Carbon
import GhosttyKit
import Testing

@testable import MultishellAppUI

@Suite
@MainActor
struct GhosttySecureInputTests {
  private final class FakeSystem {
    var isAppActive = true
    var enabled = false
    var calls = 0
  }

  private func secureInput(_ system: FakeSystem) -> GhosttySecureInput {
    GhosttySecureInput(
      isAppActive: { system.isAppActive },
      enable: {
        system.calls += 1
        system.enabled = true
        return noErr
      },
      disable: {
        system.calls += 1
        system.enabled = false
        return noErr
      })
  }

  @Test func aPasswordPromptInThePaneWithTheKeyboardTurnsItOn() {
    let system = FakeSystem()
    let input = secureInput(system)
    input.update(ObjectIdentifier(system), wantsSecureInput: true, hasKeyboard: true)
    #expect(system.enabled)
  }

  @Test func aPasswordPromptInAPaneWithoutTheKeyboardLeavesItOff() {
    let system = FakeSystem()
    let input = secureInput(system)
    input.update(ObjectIdentifier(system), wantsSecureInput: true, hasKeyboard: false)
    #expect(!system.enabled)
  }

  @Test func leavingThePromptOrClosingThePaneTurnsItOff() {
    let system = FakeSystem()
    let input = secureInput(system)
    let pane = ObjectIdentifier(system)
    input.update(pane, wantsSecureInput: true, hasKeyboard: true)
    #expect(system.enabled)
    input.update(pane, wantsSecureInput: false, hasKeyboard: true)
    #expect(!system.enabled)
    input.update(pane, wantsSecureInput: true, hasKeyboard: true)
    #expect(system.enabled)
    input.remove(pane)
    #expect(!system.enabled)
  }

  @Test func anotherAppInFrontGetsItBackAndReturningTakesItAgain() {
    let system = FakeSystem()
    let input = secureInput(system)
    input.update(ObjectIdentifier(system), wantsSecureInput: true, hasKeyboard: true)
    #expect(system.enabled)
    system.isAppActive = false
    input.applicationDidResignActive()
    #expect(!system.enabled)
    system.isAppActive = true
    input.applicationDidBecomeActive()
    #expect(system.enabled)
  }

  @Test func whileAnotherAppIsInFrontNothingIsTurnedOn() {
    let system = FakeSystem()
    system.isAppActive = false
    let input = secureInput(system)
    input.update(ObjectIdentifier(system), wantsSecureInput: true, hasKeyboard: true)
    #expect(!system.enabled)
    #expect(system.calls == 0)
  }

  @Test func withPasswordPromptsIgnoredAPromptTurnsNothingOn() {
    let system = FakeSystem()
    let input = secureInput(system)
    input.followsPasswordPrompts = false
    input.update(ObjectIdentifier(system), wantsSecureInput: true, hasKeyboard: true)
    #expect(!system.enabled)
  }

  @Test func turningPromptsOffLetsGoOfOneAlreadyOn() {
    let system = FakeSystem()
    let input = secureInput(system)
    input.update(ObjectIdentifier(system), wantsSecureInput: true, hasKeyboard: true)
    #expect(system.enabled)
    input.followsPasswordPrompts = false
    #expect(!system.enabled)
    input.followsPasswordPrompts = true
    #expect(system.enabled, "and taken again for the prompt still waiting")
  }

  @Test func aDisableMacOSRefusesIsTriedAgainNextTime() {
    let system = FakeSystem()
    var refuses = true
    let input = GhosttySecureInput(
      isAppActive: { true },
      enable: {
        system.enabled = true
        return noErr
      },
      disable: {
        guard !refuses else { return OSStatus(paramErr) }
        system.enabled = false
        return noErr
      })
    let pane = ObjectIdentifier(system)
    input.update(pane, wantsSecureInput: true, hasKeyboard: true)
    input.update(pane, wantsSecureInput: false, hasKeyboard: true)
    #expect(system.enabled, "macOS refused")
    refuses = false
    input.update(pane, wantsSecureInput: false, hasKeyboard: false)
    #expect(!system.enabled)
  }

  @Test func theKeybindTogglesAPanesPromptAndLibghosttySetsItOutright() {
    #expect(GhosttySecureInput.wantsSecureInput(after: GHOSTTY_SECURE_INPUT_ON, was: false))
    #expect(!GhosttySecureInput.wantsSecureInput(after: GHOSTTY_SECURE_INPUT_OFF, was: true))
    #expect(GhosttySecureInput.wantsSecureInput(after: GHOSTTY_SECURE_INPUT_TOGGLE, was: false))
    #expect(!GhosttySecureInput.wantsSecureInput(after: GHOSTTY_SECURE_INPUT_TOGGLE, was: true))
  }

  @Test func aPromptReportedTwiceTurnsItOnOnlyOnce() {
    let system = FakeSystem()
    let input = secureInput(system)
    input.update(ObjectIdentifier(system), wantsSecureInput: true, hasKeyboard: true)
    input.update(ObjectIdentifier(system), wantsSecureInput: true, hasKeyboard: true)
    #expect(system.calls == 1)
  }
}
