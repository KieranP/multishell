import AppKit
import Observation
import SwiftUI
import Testing

@testable import MultishellAppUI

@Suite @MainActor
struct SettingsNumberFieldTests {
  @Observable
  final class Stored {
    var value = 10
  }

  /// Stands in for the store, which clamps the port block fields as it saves them.
  private struct ClampingRow: View {
    let stored: Stored

    var body: some View {
      SettingsNumberField(
        "Port",
        value: Binding(get: { stored.value }, set: { stored.value = min($0, 100) }),
      )
    }
  }

  @Test func aNumberTheStoreClampsShowsWhatWasSavedOnceEntered() throws {
    let stored = Stored()
    let host = NSHostingView(rootView: ClampingRow(stored: stored))
    let window = OffscreenWindow.holding(
      host,
      rect: NSRect(x: 0, y: 0, width: 200, height: 60),
      deferred: false,
    )
    OffscreenWindow.settle(within: 0.1)
    let field = try #require(host.descendants(of: NSTextField.self).first { $0.isEditable })
    #expect(window.makeFirstResponder(field))
    let editor = try #require(field.currentEditor() as? NSTextView)

    editor.selectAll(nil)
    editor.insertText("500", replacementRange: editor.selectedRange())
    editor.insertNewline(nil)
    OffscreenWindow.settle(within: 0.2)

    #expect(stored.value == 100)
    #expect(field.stringValue == "100")
  }
}
