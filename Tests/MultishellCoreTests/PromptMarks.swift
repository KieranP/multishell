/// The OSC 133 marks the shell integration writes around a prompt.
enum PromptMarks {
  static let claim = "\u{1B}]133;A;cl=line\u{7}"
  static let plainStart = "\u{1B}]133;A\u{7}"
  static let input = "\u{1B}]133;B\u{7}"
  static let output = "\u{1B}]133;C\u{7}"
}
