import Carbon
import GhosttyKit
import Testing

@testable import MultishellAppUI

@Suite
@MainActor
struct GhosttySecureInputTests {
  private final class FakeSystem {
    var isAppActive = true
    var isEnabled = false
    var callCount = 0
  }

  private func secureInput(_ system: FakeSystem) -> GhosttySecureInput {
    GhosttySecureInput(
      isAppActive: { system.isAppActive },
      enable: {
        system.callCount += 1
        system.isEnabled = true
        return noErr
      },
      disable: {
        system.callCount += 1
        system.isEnabled = false
        return noErr
      },
    )
  }

  @Test func aPasswordPromptInThePaneWithTheKeyboardTurnsItOn() {
    let system = FakeSystem()
    let input = secureInput(system)
    input.update(ObjectIdentifier(system), wantsSecureInput: true, hasKeyboard: true)
    #expect(system.isEnabled)
  }

  @Test func aPasswordPromptInAPaneWithoutTheKeyboardLeavesItOff() {
    let system = FakeSystem()
    let input = secureInput(system)
    input.update(ObjectIdentifier(system), wantsSecureInput: true, hasKeyboard: false)
    #expect(!system.isEnabled)
  }

  @Test func leavingThePromptOrClosingThePaneTurnsItOff() {
    let system = FakeSystem()
    let input = secureInput(system)
    let pane = ObjectIdentifier(system)
    input.update(pane, wantsSecureInput: true, hasKeyboard: true)
    #expect(system.isEnabled)
    input.update(pane, wantsSecureInput: false, hasKeyboard: true)
    #expect(!system.isEnabled)
    input.update(pane, wantsSecureInput: true, hasKeyboard: true)
    #expect(system.isEnabled)
    input.remove(pane)
    #expect(!system.isEnabled)
  }

  @Test func anotherAppInFrontGetsItBackAndReturningTakesItAgain() {
    let system = FakeSystem()
    let input = secureInput(system)
    input.update(ObjectIdentifier(system), wantsSecureInput: true, hasKeyboard: true)
    #expect(system.isEnabled)
    system.isAppActive = false
    input.applicationDidResignActive()
    #expect(!system.isEnabled)
    system.isAppActive = true
    input.applicationDidBecomeActive()
    #expect(system.isEnabled)
  }

  @Test func whileAnotherAppIsInFrontNothingIsTurnedOn() {
    let system = FakeSystem()
    system.isAppActive = false
    let input = secureInput(system)
    input.update(ObjectIdentifier(system), wantsSecureInput: true, hasKeyboard: true)
    #expect(!system.isEnabled)
    #expect(system.callCount == 0)
  }

  @Test func withPasswordPromptsIgnoredAPromptTurnsNothingOn() {
    let system = FakeSystem()
    let input = secureInput(system)
    input.followsPasswordPrompts = false
    input.update(ObjectIdentifier(system), wantsSecureInput: true, hasKeyboard: true)
    #expect(!system.isEnabled)
  }

  @Test func turningPromptsOffLetsGoOfOneAlreadyOn() {
    let system = FakeSystem()
    let input = secureInput(system)
    input.update(ObjectIdentifier(system), wantsSecureInput: true, hasKeyboard: true)
    #expect(system.isEnabled)
    input.followsPasswordPrompts = false
    #expect(!system.isEnabled)
    input.followsPasswordPrompts = true
    #expect(system.isEnabled, "and taken again for the prompt still waiting")
  }

  @Test func aDisableMacOSRefusesIsTriedAgainNextTime() {
    let system = FakeSystem()
    var refuses = true
    let input = GhosttySecureInput(
      isAppActive: { true },
      enable: {
        system.isEnabled = true
        return noErr
      },
      disable: {
        guard !refuses else { return OSStatus(paramErr) }
        system.isEnabled = false
        return noErr
      },
    )
    let pane = ObjectIdentifier(system)
    input.update(pane, wantsSecureInput: true, hasKeyboard: true)
    input.update(pane, wantsSecureInput: false, hasKeyboard: true)
    #expect(system.isEnabled, "macOS refused")
    refuses = false
    input.update(pane, wantsSecureInput: false, hasKeyboard: false)
    #expect(!system.isEnabled)
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
    #expect(system.callCount == 1)
  }
}
