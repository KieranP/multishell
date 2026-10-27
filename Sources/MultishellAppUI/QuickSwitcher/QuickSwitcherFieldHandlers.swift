import MultishellCore

/// What the quick switcher's field hands on: its text, the keys that are not
/// typing, and its losing the keyboard.
@MainActor
struct QuickSwitcherFieldHandlers {
  /// Hands the model an edit and answers with the text it kept, which a `>`
  /// rewrites.
  let setText: (String) -> String
  /// Whether text is being composed, an input method's still unconfirmed.
  let onCompose: (Bool) -> Void
  /// Up and Down.
  let move: (CycleDirection) -> Void
  /// Tab and Shift+Tab.
  let stepScope: (CycleDirection) -> Void
  let onBackspaceWhenEmpty: () -> Void
  /// Return.
  let choose: () -> Void
  /// Escape.
  let close: () -> Void
  /// The keyboard went to something else.
  let onEndEditing: () -> Void
}
