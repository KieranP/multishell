import AppKit
import MultishellCore
import Testing

@testable import MultishellAppCore
@testable import MultishellAppUI

@Suite @MainActor
struct DiffTextViewChangesRotorTests {
  @Test func theChangesRotorWalksChangedLinesBothWays() throws {
    let (view, window) = DiffDocumentFixture.shown(rows: 12)
    defer { withExtendedLifetime(window) {} }
    let textView = view.textView
    let rotor = try #require(textView.accessibilityCustomRotors().first)
    let forward = NSAccessibilityCustomRotor.SearchParameters()
    forward.searchDirection = .next

    let first = try #require(textView.rotor(rotor, resultFor: forward))
    forward.currentItem = first
    let second = try #require(textView.rotor(rotor, resultFor: forward))
    let back = NSAccessibilityCustomRotor.SearchParameters()
    back.searchDirection = .previous
    back.currentItem = second

    #expect(first.customLabel == "Removed, unstaged, was line 4: gone 3")
    #expect(second.customLabel?.hasPrefix("Added, unstaged, line 6") == true)
    #expect(textView.rotor(rotor, resultFor: back)?.customLabel == first.customLabel)
  }

  @Test func theRotorFindsNothingOnceTheFileIsEmptied() throws {
    let (view, window) = DiffDocumentFixture.shown(rows: 12)
    defer { withExtendedLifetime(window) {} }
    let textView = view.textView
    let rotor = try #require(textView.accessibilityCustomRotors().first)
    let forward = NSAccessibilityCustomRotor.SearchParameters()
    forward.searchDirection = .next
    let first = try #require(textView.rotor(rotor, resultFor: forward))
    forward.currentItem = first

    view.show(DiffDisplayText([], marksStaging: true), theme: Theme.builtins[0])

    #expect(textView.rotor(rotor, resultFor: forward) == nil)
  }
}
