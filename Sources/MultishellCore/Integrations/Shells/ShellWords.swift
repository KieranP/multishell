/// A line split into words as a shell splits it, quotes and escapes taken off.
public enum ShellWords {
  private static let launchers: Set<String> = ["env", "command", "exec"]
  /// `env -u NAME` and `exec -a NAME`, whose value is not the program.
  private static let optionsTakingAValue: Set<String> = ["-u", "-a"]

  /// Words the way a shell reads them, by scalar so a combining mark cannot hide a
  /// quote. A quote left open takes the rest of the line, there being nobody to ask.
  public static func split(_ line: String) -> [String] {
    var words: [String] = []
    var word = ""
    var hasWord = false
    var quote: Unicode.Scalar?
    var escaping = false
    for scalar in line.unicodeScalars {
      if escaping {
        // Inside double quotes a backslash guards only these four, so
        // `"\d+"` keeps its backslash where `\d` outside quotes loses it.
        if quote == "\"", !#"\"$`"#.unicodeScalars.contains(scalar) {
          word.unicodeScalars.append("\\")
        }
        word.unicodeScalars.append(scalar)
        hasWord = true
        escaping = false
      } else if scalar == "\\", quote != "'" {
        // A word starts on the escaped scalar, not the backslash: a
        // trailing one would otherwise pass an empty final argument.
        escaping = true
      } else if let open = quote {
        if scalar == open { quote = nil } else { word.unicodeScalars.append(scalar) }
        hasWord = true
      } else if scalar == "'" || scalar == "\"" {
        // As with the escape, the word starts on what the quote carries,
        // never the opening mark: half a flag being typed passes nothing.
        quote = scalar
      } else if scalar.properties.isWhitespace {
        if hasWord { words.append(word) }
        word = ""
        hasWord = false
      } else {
        word.unicodeScalars.append(scalar)
        hasWord = true
      }
    }
    if hasWord { words.append(word) }
    return words
  }

  /// The program a line runs: past leading `NAME=value` words and `env`, `command`
  /// or `exec` with their options, `nil` where none is left.
  public static func program(of line: String) -> String? {
    var isAfterLauncher = false
    var skipsNext = false
    for word in split(line) {
      if skipsNext {
        skipsNext = false
      } else if isAssignment(word) {
        continue
      } else if launchers.contains(word) {
        isAfterLauncher = true
      } else if isAfterLauncher, word.hasPrefix("-") {
        skipsNext = optionsTakingAValue.contains(word)
      } else {
        return word
      }
    }
    return nil
  }

  private static func isAssignment(_ word: String) -> Bool {
    guard let equals = word.firstIndex(of: "="), equals != word.startIndex else { return false }
    let name = word[..<equals]
    return name.first.map { !$0.isNumber } == true
      && name.allSatisfy { $0 == "_" || ($0.isASCII && ($0.isLetter || $0.isNumber)) }
  }
}
