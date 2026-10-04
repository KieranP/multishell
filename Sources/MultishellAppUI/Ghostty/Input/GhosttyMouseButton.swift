import GhosttyKit

/// AppKit's button numbers in libghostty's names, after Ghostty's own
/// `MouseButton(fromNSEventButtonNumber:)`.
enum GhosttyMouseButton {
  /// Indexed by AppKit's number. Back and forward come fourth and fifth, the
  /// buttons xterm calls 8 and 9.
  private static let buttons: [ghostty_input_mouse_button_e] = [
    GHOSTTY_MOUSE_LEFT, GHOSTTY_MOUSE_RIGHT, GHOSTTY_MOUSE_MIDDLE,
    GHOSTTY_MOUSE_EIGHT, GHOSTTY_MOUSE_NINE,
    GHOSTTY_MOUSE_SIX, GHOSTTY_MOUSE_SEVEN, GHOSTTY_MOUSE_FOUR, GHOSTTY_MOUSE_FIVE,
    GHOSTTY_MOUSE_TEN, GHOSTTY_MOUSE_ELEVEN,
  ]

  static func button(forNumber number: Int) -> ghostty_input_mouse_button_e {
    buttons.indices.contains(number) ? buttons[number] : GHOSTTY_MOUSE_UNKNOWN
  }
}
