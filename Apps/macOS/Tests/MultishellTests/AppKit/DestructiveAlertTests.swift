import AppKit
import Testing

@testable import Multishell

@Suite
@MainActor
struct DestructiveAlertTests {
  private func alert(choices: [String]) -> NSAlert {
    let alert = DestructiveAlert.make(
      title: "Remove worktree feat?", message: "Moves it to the Trash.",
      choices: choices, cancel: "Abbrechen")
    alert.layout()
    return alert
  }

  @Test func everyChoiceIsDestructiveAndTheCancelTakesEscape() {
    let buttons = alert(choices: ["Remove Worktree and Branch", "Remove Worktree"]).buttons
    #expect(buttons.map(\.hasDestructiveAction) == [true, true, false])
    #expect(buttons.last?.keyEquivalent == "\u{1b}")
  }

  /// AppKit takes Return off a destructive button at every layout, which is
  /// why presenting puts it back rather than `make` alone setting it.
  @Test func aLayoutTakesReturnOffTheLeadChoiceAndItGoesBackOn() {
    let alert = alert(choices: ["Remove Worktree"])
    #expect(alert.buttons.first?.keyEquivalent == "")
    DestructiveAlert.leadTakesReturn(alert)
    #expect(alert.buttons.first?.keyEquivalent == "\r")
  }

  @Test func withNothingToLeadWithTheCancelKeepsReturn() {
    #expect(alert(choices: []).buttons.map(\.keyEquivalent) == ["\r"])
  }

  @Test func theLeadChoiceIsPaintedRedOverTheDefaultButtonsAccent() {
    let alert = alert(choices: ["Remove Worktree"])
    DestructiveAlert.leadTakesReturn(alert)
    #expect(alert.buttons.first?.keyEquivalent == "\r")
    #expect(alert.buttons.first?.bezelColor == .systemRed)
  }

  @Test func theResponseNamesWhichChoiceWasPressed() {
    #expect(DestructiveAlert.chosen(.alertFirstButtonReturn, of: 2) == 0)
    #expect(DestructiveAlert.chosen(.alertSecondButtonReturn, of: 2) == 1)
    #expect(DestructiveAlert.chosen(.alertThirdButtonReturn, of: 2) == nil)
    #expect(DestructiveAlert.chosen(.cancel, of: 2) == nil)
  }
}
