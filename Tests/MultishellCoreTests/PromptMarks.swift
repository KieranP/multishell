/// The OSC 133 marks the shell integration writes around a prompt.
enum PromptMarks {
  static let claim = "\u{1B}]133;A;cl=line\u{7}"
  static let input = "\u{1B}]133;B\u{7}"
  static let output = "\u{1B}]133;C\u{7}"
  /// The start of any command end, for whether one was written at all.
  static let anyCommandEnd = "\u{1B}]133;D"

  static func commandEnd(_ status: Int) -> String { "\u{1B}]133;D;\(status)\u{7}" }
}
