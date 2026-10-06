/// The title, cursor and directory escapes the zsh integration writes beside its marks.
enum TerminalReports {
  /// The start of any title, for whether one was set at all.
  static let anyTitle = "\u{1B}]2;"

  /// A directory report up to its host and path.
  static let directoryPrefix = "\u{1B}]7;kitty-shell-cwd://"

  static func title(_ text: String) -> String { "\u{1B}]2;\(text)\u{7}" }

  /// 0 is the user's own shape, 1 and 2 a block, 5 and 6 a bar; odd blinks.
  static func cursorShape(_ shape: Int) -> String { "\u{1B}[\(shape) q" }
}
