/// JSON with `//` and `/* */` comments, as one agent's settings file allows,
/// turned into plain JSON by blanking each comment outside a string.
enum JSONComments {
  static func blanked(in text: String) -> String {
    var output = ""
    var characters = text.makeIterator()
    var isInString = false
    while let character = characters.next() {
      if isInString {
        output.append(character)
        if character == "\\", let escaped = characters.next() {
          output.append(escaped)
        } else if character == "\"" {
          isInString = false
        }
        continue
      }
      guard character == "/" else {
        if character == "\"" { isInString = true }
        output.append(character)
        continue
      }
      switch characters.next() {
      case "/":
        while let skipped = characters.next(), !skipped.isNewline {}
        output.append("\n")

      case "*":
        var previous: Character?
        while let skipped = characters.next(), !(previous == "*" && skipped == "/") {
          previous = skipped
        }
        output.append(" ")

      case let other:
        output.append(character)
        if let other { output.append(other) }
        if other == "\"" { isInString = true }
      }
    }
    return output
  }
}
