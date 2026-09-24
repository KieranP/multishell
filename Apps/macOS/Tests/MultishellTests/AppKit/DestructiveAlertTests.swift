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

  /// macOS 27's alert button keeps no bezel colour, and draws a destructive one
  /// red itself, so there it is the drawing that is read.
  @Test func theLeadChoiceIsPaintedRedOverTheDefaultButtonsAccent() throws {
    let alert = alert(choices: ["Remove Worktree"])
    DestructiveAlert.leadTakesReturn(alert)
    let lead = try #require(alert.buttons.first)
    #expect(lead.keyEquivalent == "\r")
    guard lead.bezelColor == nil else {
      #expect(lead.bezelColor == .systemRed)
      return
    }
    let bezel = try #require(bezelColour(of: lead, in: alert))
    #expect(
      bezel.redComponent > bezel.greenComponent + 0.08
        && bezel.redComponent > bezel.blueComponent + 0.08, "\(bezel)")
  }

  /// A point inside the bezel clear of the title, from the alert drawn offscreen.
  private func bezelColour(of button: NSButton, in alert: NSAlert) -> NSColor? {
    guard let view = alert.window.contentView,
      let image = view.bitmapImageRepForCachingDisplay(in: view.bounds)
    else { return nil }
    view.layoutSubtreeIfNeeded()
    view.cacheDisplay(in: view.bounds, to: image)
    let frame = button.convert(button.bounds, to: view)
    let scale = CGFloat(image.pixelsWide) / view.bounds.width
    let x = Int((frame.minX + 12) * scale)
    let y = Int((view.isFlipped ? frame.midY : view.bounds.height - frame.midY) * scale)
    return image.colorAt(x: x, y: y)?.usingColorSpace(.sRGB)
  }

  @Test func theResponseNamesWhichChoiceWasPressed() {
    #expect(DestructiveAlert.chosen(.alertFirstButtonReturn, of: 2) == 0)
    #expect(DestructiveAlert.chosen(.alertSecondButtonReturn, of: 2) == 1)
    #expect(DestructiveAlert.chosen(.alertThirdButtonReturn, of: 2) == nil)
    #expect(DestructiveAlert.chosen(.cancel, of: 2) == nil)
  }
}
