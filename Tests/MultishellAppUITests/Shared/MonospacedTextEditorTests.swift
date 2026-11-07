import AppKit
import Observation
import SwiftUI
import Testing

@testable import MultishellAppUI

@Suite @MainActor
struct MonospacedTextEditorTests {
  @Observable
  final class Stored {
    var text = ""
    var otherText = "B message"
    var editsOther = false
    var showsEditor = true
    var isEnabled = true
  }

  private struct Editor: View {
    @Bindable var stored: Stored

    var body: some View {
      if stored.showsEditor {
        MonospacedTextEditor(
          text: stored.editsOther ? $stored.otherText : $stored.text,
          placeholder: nil,
          fontSize: 12,
          fill: Color.clear,
          border: nil,
          minHeight: 60,
          maxHeight: 120,
        )
        .disabled(!stored.isEnabled)
      }
    }
  }

  private static func textView(editing stored: Stored) throws -> (NSTextView, NSWindow) {
    let host = NSHostingView(rootView: Editor(stored: stored))
    let window = OffscreenWindow.holding(
      host,
      rect: NSRect(x: 0, y: 0, width: 300, height: 140),
      deferred: false,
    )
    OffscreenWindow.settle(within: 0.1)
    let textView = try #require(host.descendants(of: NSTextView.self).first { $0.isEditable })
    return (textView, window)
  }

  @Test func aScriptIsNeverRewrittenWithSmartQuotesDashesOrCorrections() throws {
    let (textView, window) = try Self.textView(editing: Stored())

    withExtendedLifetime(window) {
      #expect(!textView.isAutomaticQuoteSubstitutionEnabled)
      #expect(!textView.isAutomaticDashSubstitutionEnabled)
      #expect(!textView.isAutomaticTextReplacementEnabled)
      #expect(!textView.isAutomaticSpellingCorrectionEnabled)
    }
  }

  @Test func whatIsTypedReachesTheBindingAsTyped() throws {
    let stored = Stored()
    let (textView, window) = try Self.textView(editing: stored)
    #expect(window.makeFirstResponder(textView))

    textView.insertText(#"echo "hi" --x"#, replacementRange: textView.selectedRange())
    OffscreenWindow.settle(within: 0.1)

    withExtendedLifetime(window) { #expect(stored.text == #"echo "hi" --x"#) }
  }

  @Test func undoAfterTheTextWasReplacedFromOutsideNeitherCrashesNorBringsTheOldTextBack() throws {
    let stored = Stored()
    let (textView, window) = try Self.textView(editing: stored)
    #expect(window.makeFirstResponder(textView))
    textView.insertText("abcdef", replacementRange: textView.selectedRange())
    OffscreenWindow.settle(within: 0.1)

    stored.text = "xy"
    OffscreenWindow.settle(within: 0.1)
    let undoManager = try #require(textView.undoManager)
    if undoManager.canUndo { undoManager.undo() }
    OffscreenWindow.settle(within: 0.1)

    withExtendedLifetime(window) {
      #expect(stored.text == "xy")
      #expect(textView.string == "xy")
    }
  }

  @Test func undoAfterTheEditorIsGoneLeavesWhatWasTypedAlone() throws {
    let stored = Stored()
    let (textView, window) = try Self.textView(editing: stored)
    #expect(window.makeFirstResponder(textView))
    textView.insertText("echo hi", replacementRange: textView.selectedRange())
    OffscreenWindow.settle(within: 0.1)
    let undoManager = try #require(textView.undoManager)

    stored.showsEditor = false
    OffscreenWindow.settle(within: 0.1)
    if undoManager.canUndo { undoManager.undo() }
    OffscreenWindow.settle(within: 0.1)

    withExtendedLifetime(window) { #expect(stored.text == "echo hi") }
  }

  @Test func aDisabledEditorWithTheKeyboardTakesNoTyping() throws {
    let stored = Stored()
    let (textView, window) = try Self.textView(editing: stored)
    #expect(window.makeFirstResponder(textView))

    stored.isEnabled = false
    OffscreenWindow.settle(within: 0.1)
    textView.insertText("typed", replacementRange: textView.selectedRange())
    OffscreenWindow.settle(within: 0.1)

    withExtendedLifetime(window) {
      #expect(stored.text == "")
      #expect(textView.string == "")
    }
  }

  @Test func undoAfterTheEditorMovesToAnotherBindingLeavesThatOneAlone() throws {
    let stored = Stored()
    let (textView, window) = try Self.textView(editing: stored)
    #expect(window.makeFirstResponder(textView))
    textView.insertText("A typed", replacementRange: textView.selectedRange())
    OffscreenWindow.settle(within: 0.1)

    stored.editsOther = true
    OffscreenWindow.settle(within: 0.1)
    let undoManager = try #require(textView.undoManager)
    if undoManager.canUndo { undoManager.undo() }
    OffscreenWindow.settle(within: 0.1)

    withExtendedLifetime(window) {
      #expect(stored.otherText == "B message")
      #expect(stored.text == "A typed")
    }
  }
}
