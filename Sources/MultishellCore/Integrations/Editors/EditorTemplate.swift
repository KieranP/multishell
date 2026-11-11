/// Where a custom editor template takes the path: at its placeholder, else after the
/// command's words, since past a trailing `&`, `;` or comment it would run or be lost.
enum EditorTemplate {
  private static let operators: Set<Unicode.Scalar> = [";", "&", "|", "(", ")"]

  /// `template` as is where `token` sits before any comment, else with it placed.
  static func placing(_ token: String, in template: String) -> String {
    let scalars = Array(template.unicodeScalars)
    let commentStart = commentStart(in: scalars)
    let text = { (range: Range<Int>) in String(String.UnicodeScalarView(scalars[range])) }
    if text(0..<commentStart).contains(token) { return template }
    var end = commentStart
    while end > 0, scalars[end - 1].properties.isWhitespace { end -= 1 }
    var commandEnd = end
    while commandEnd > 0, !isEscaped(commandEnd - 1, in: scalars),
      ["&", ";"].contains(scalars[commandEnd - 1])
        || scalars[commandEnd - 1].properties.isWhitespace
    {
      commandEnd -= 1
    }
    let comment = commentStart < scalars.count ? text(end..<scalars.count) : ""
    return text(0..<commandEnd) + " " + token + text(commandEnd..<end) + comment
  }

  /// Where an unquoted `#` starts a word, as a shell reads a comment, or the end.
  private static func commentStart(in scalars: [Unicode.Scalar]) -> Int {
    var quote: Unicode.Scalar?
    var index = 0
    while index < scalars.count {
      let scalar = scalars[index]
      if scalar == "\\", quote != "'" {
        index += 1
      } else if let open = quote {
        if scalar == open { quote = nil }
      } else if scalar == "'" || scalar == "\"" {
        quote = scalar
      } else if scalar == "#",
        index == 0 || scalars[index - 1].properties.isWhitespace
          || operators.contains(scalars[index - 1])
      {
        return index
      }
      index += 1
    }
    return scalars.count
  }

  /// Behind an odd run of backslashes, so the shell reads it as text.
  private static func isEscaped(_ index: Int, in scalars: [Unicode.Scalar]) -> Bool {
    var backslashes = 0
    var before = index - 1
    while before >= 0, scalars[before] == "\\" {
      backslashes += 1
      before -= 1
    }
    return backslashes % 2 == 1
  }
}
