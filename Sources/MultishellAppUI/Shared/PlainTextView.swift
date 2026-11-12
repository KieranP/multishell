import AppKit
import SwiftUI

/// Multi-line text kept as typed: SwiftUI's `TextEditor` turns `"` and `--` into
/// curly quotes and dashes, which break a hook script, and offers no way to stop it.
struct PlainTextView: NSViewRepresentable {
  @Binding var text: String
  let fontSize: Double
  /// ⌘↩, where the field has something to submit.
  var commit: (() -> Void)?
  /// Escape, where the field can be dismissed.
  var cancel: (() -> Void)?
  var takesKeyboardOnAppear = false
  var onTookKeyboard: (() -> Void)?
  var colors: PlainTextColors?

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
    let scrollView = NSScrollView()
    scrollView.drawsBackground = false
    scrollView.hasVerticalScroller = true
    scrollView.autohidesScrollers = true
    let textView = KeyCommandTextView(usingTextLayoutManager: true)
    textView.autoresizingMask = [.width]
    textView.isVerticallyResizable = true
    textView.isHorizontallyResizable = false
    textView.maxSize = NSSize(
      width: CGFloat.greatestFiniteMagnitude,
      height: .greatestFiniteMagnitude,
    )
    textView.textContainer?.widthTracksTextView = true
    scrollView.documentView = textView
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
    if takesKeyboardOnAppear {
      // A turn later, once the view is in its window.
      Task { @MainActor [weak textView, onTookKeyboard] in
        guard let textView, textView.window?.makeFirstResponder(textView) == true else { return }
        onTookKeyboard?()
      }
    }
    return scrollView
  }

  func updateNSView(_ scrollView: NSScrollView, context: Context) {
    context.coordinator.text = $text
    guard let textView = scrollView.documentView as? KeyCommandTextView else { return }
    textView.commit = commit
    textView.cancel = cancel
    if let colors {
      // The area's text and selection, the caret in its text, as a themed field's are.
      textView.textColor = colors.text
      textView.insertionPointColor = colors.text
      textView.selectedTextAttributes = [.backgroundColor: colors.selection]
    }
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
