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

    field.keyDown(with: try keyDown("\r", keyCode: 36, flags: .command))
    field.keyDown(with: try keyDown("\u{1B}", keyCode: 53))

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

    field.keyDown(with: try keyDown("\r", keyCode: 36, flags: [.command, .capsLock]))
    field.keyDown(
      with: try keyDown("\u{3}", keyCode: 76, flags: [.command, .numericPad])
    )
    field.keyDown(with: try keyDown("\u{1B}", keyCode: 53, flags: .capsLock))

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

    field.keyDown(with: try keyDown("\u{1B}", keyCode: 53))

    #expect(calls.cancels == 0)
  }

  @Test func addingRightAfterTypingCommitsWhatWasTyped() throws {
    let calls = Calls()
    let (field, window) = try #require(Self.shown(calls))
    defer { withExtendedLifetime(window) {} }
    window.makeFirstResponder(field)

    field.insertText("Fix it.", replacementRange: field.selectedRange())
    field.keyDown(with: try keyDown("\r", keyCode: 36, flags: .command))

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
