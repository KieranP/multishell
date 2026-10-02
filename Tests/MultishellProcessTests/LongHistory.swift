/// A zsh-format history longer than any `HISTFILESIZE` a test sets, so a
/// shell that trimmed it on exit would show.
enum LongHistory {
  static let lines = (1...600).map { ": 1700000000:0;command \($0)\n" }.joined()
}
