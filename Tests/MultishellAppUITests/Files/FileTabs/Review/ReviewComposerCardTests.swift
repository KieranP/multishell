import AppKit
import MultishellCore
import SwiftUI
import Testing

@testable import MultishellAppCore
@testable import MultishellAppUI

@Suite @MainActor
struct ReviewComposerCardTests {
  private final class Calls {
    var commits = 0
    var cancels = 0
    var noted = ""
    var notedAtCommit: String?
  }

  private static func shown(_ calls: Calls) -> (NSTextView, NSWindow)? {
    let card = ReviewComposerCard(
      composer: ReviewComposer(
        path: "a.txt",
        side: .onDisk,
        lines: 3...3,
        quote: ["x"],
        scope: .modified,
        editing: nil,
      ),
      draft: "",
      theme: Theme.builtins[0],
      metrics: UIMetrics(fontSize: 13, fontFamily: nil),
      noteDraft: { calls.noted = $0 },
      commit: {
        calls.commits += 1
        calls.notedAtCommit = calls.noted
      },
      cancel: { calls.cancels += 1 },
      takesKeyboardOnAppear: false,
      onTookKeyboard: {},
    )
    let host = NSHostingView(rootView: card)
    let window = OffscreenWindow.holding(
      host,
      rect: NSRect(x: 0, y: 0, width: 400, height: 200),
      deferred: false,
    )
    OffscreenWindow.settle(within: 0.1)
    guard let field = host.descendants(of: NSTextView.self).first else { return nil }
    return (field, window)
  }

  private static func key(
    _ characters: String,
    code: UInt16,
    modifiers: NSEvent.ModifierFlags,
  ) -> NSEvent? {
    NSEvent.keyEvent(
      with: .keyDown,
      location: .zero,
      modifierFlags: modifiers,
      timestamp: 0,
      windowNumber: 0,
      context: nil,
      characters: characters,
      charactersIgnoringModifiers: characters,
      isARepeat: false,
      keyCode: code,
    )
  }

  @Test func theFieldKeepsQuotesAndDashesAsTyped() throws {
    let (field, window) = try #require(Self.shown(Calls()))
    defer { withExtendedLifetime(window) {} }

    #expect(!field.isAutomaticQuoteSubstitutionEnabled)
    #expect(!field.isAutomaticDashSubstitutionEnabled)
  }

  @Test func commandReturnAddsAndEscapeCancels() throws {
    let calls = Calls()
    let (field, window) = try #require(Self.shown(calls))
    defer { withExtendedLifetime(window) {} }
    window.makeFirstResponder(field)
    field.insertText("Fix it.", replacementRange: field.selectedRange())

    field.keyDown(with: try #require(Self.key("\r", code: 36, modifiers: .command)))
    field.keyDown(with: try #require(Self.key("\u{1B}", code: 53, modifiers: [])))

    #expect(calls.commits == 1)
    #expect(calls.cancels == 1)
    #expect(field.string == "Fix it.")
  }

  @Test func capsLockAndTheKeypadsEnterStillAddAndCancel() throws {
    let calls = Calls()
    let (field, window) = try #require(Self.shown(calls))
    defer { withExtendedLifetime(window) {} }
    window.makeFirstResponder(field)
    field.insertText("Fix it.", replacementRange: field.selectedRange())

    field.keyDown(with: try #require(Self.key("\r", code: 36, modifiers: [.command, .capsLock])))
    field.keyDown(
      with: try #require(Self.key("\u{3}", code: 76, modifiers: [.command, .numericPad]))
    )
    field.keyDown(with: try #require(Self.key("\u{1B}", code: 53, modifiers: .capsLock)))

    #expect(calls.commits == 2)
    #expect(calls.cancels == 1)
  }

  @Test func escapeWhileAnInputMethodIsComposingLeavesTheComposerOpen() throws {
    let calls = Calls()
    let (field, window) = try #require(Self.shown(calls))
    defer { withExtendedLifetime(window) {} }
    window.makeFirstResponder(field)
    field.setMarkedText(
      "か",
      selectedRange: NSRange(location: 1, length: 0),
      replacementRange: field.selectedRange(),
    )

    field.keyDown(with: try #require(Self.key("\u{1B}", code: 53, modifiers: [])))

    #expect(calls.cancels == 0)
  }

  @Test func addingRightAfterTypingCommitsWhatWasTyped() throws {
    let calls = Calls()
    let (field, window) = try #require(Self.shown(calls))
    defer { withExtendedLifetime(window) {} }
    window.makeFirstResponder(field)

    field.insertText("Fix it.", replacementRange: field.selectedRange())
    field.keyDown(with: try #require(Self.key("\r", code: 36, modifiers: .command)))

    #expect(calls.notedAtCommit == "Fix it.")
  }

  @Test func theTextIsAtLeastAsTallAsTheFieldSoNoClickFallsBelowIt() throws {
    let (field, window) = try #require(Self.shown(Calls()))
    defer { withExtendedLifetime(window) {} }
    let clip = try #require(field.enclosingScrollView?.contentView)

    #expect(field.frame.height >= clip.bounds.height)
  }

  @Test func theFieldTakesTheFileTabsTextAndSelectionColours() throws {
    let (field, window) = try #require(Self.shown(Calls()))
    defer { withExtendedLifetime(window) {} }
    let theme = Theme.builtins[0]

    #expect(field.textColor == theme.fileText)
    #expect(field.insertionPointColor == theme.fileText)
    #expect(field.selectedTextAttributes[.backgroundColor] as? NSColor == theme.fileSelection)
  }
}
