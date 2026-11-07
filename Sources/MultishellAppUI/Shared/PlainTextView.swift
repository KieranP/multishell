import AppKit
import SwiftUI

/// Multi-line text kept as typed: SwiftUI's `TextEditor` turns `"` and `--` into
/// curly quotes and dashes, which break a hook script, and offers no way to stop it.
struct PlainTextView: NSViewRepresentable {
  @Binding var text: String
  let fontSize: Double

  /// Its undo steps are the window's, and an Undo after the page left would edit
  /// text nobody sees and save it.
  static func dismantleNSView(_ scrollView: NSScrollView, coordinator: PlainTextViewDelegate) {
    guard let textView = scrollView.documentView as? NSTextView else { return }
    textView.textStorage?.delegate = nil
    forgetUndoSteps(of: textView)
  }

  private static func forgetUndoSteps(of textView: NSTextView) {
    textView.undoManager?.removeAllActions(withTarget: textView)
    if let textStorage = textView.textStorage {
      textView.undoManager?.removeAllActions(withTarget: textStorage)
    }
  }

  func makeNSView(context: Context) -> NSScrollView {
    let scrollView = NSTextView.scrollableTextView()
    scrollView.drawsBackground = false
    scrollView.autohidesScrollers = true
    guard let textView = scrollView.documentView as? NSTextView else { return scrollView }
    textView.string = text
    textView.isRichText = false
    textView.allowsUndo = true
    textView.drawsBackground = false
    textView.isAutomaticQuoteSubstitutionEnabled = false
    textView.isAutomaticDashSubstitutionEnabled = false
    textView.isAutomaticTextReplacementEnabled = false
    textView.isAutomaticSpellingCorrectionEnabled = false
    textView.isAutomaticLinkDetectionEnabled = false
    textView.isContinuousSpellCheckingEnabled = false
    textView.smartInsertDeleteEnabled = false
    textView.textStorage?.delegate = context.coordinator
    return scrollView
  }

  func updateNSView(_ scrollView: NSScrollView, context: Context) {
    context.coordinator.text = $text
    guard let textView = scrollView.documentView as? NSTextView else { return }
    // `.disabled` stops clicks only; a view already holding the keyboard kept typing.
    textView.isEditable = context.environment.isEnabled
    let font = NSFont.monospacedSystemFont(ofSize: fontSize, weight: .regular)
    if textView.font != font { textView.font = font }
    // Text from outside, another worktree's message or a restored default, ends
    // the undo history: its steps would apply to text the binding no longer holds.
    if !textView.hasMarkedText(), textView.string != text {
      Self.forgetUndoSteps(of: textView)
      textView.string = text
    }
  }

  func makeCoordinator() -> PlainTextViewDelegate {
    PlainTextViewDelegate(text: $text)
  }
}
