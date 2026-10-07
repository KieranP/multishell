extension String {
  /// The text with `//` and `/* */` comments stripped, outside strings only,
  /// where a URL's `//` is text.
  var withoutJSONComments: String {
    var stripped = ""
    var characters = makeIterator()
    var inString = false
    var pending = characters.next()
    while let character = pending {
      pending = characters.next()
      if inString {
        stripped.append(character)
        if character == "\\", let escaped = pending {
          stripped.append(escaped)
          pending = characters.next()
        } else if character == "\"" {
          inString = false
        }
      } else if character == "/", pending == "/" {
        while let skipped = pending, skipped != "\n" { pending = characters.next() }
      } else if character == "/", pending == "*" {
        pending = characters.next()
        var previous: Character?
        while let skipped = pending {
          pending = characters.next()
          if previous == "*", skipped == "/" { break }
          previous = skipped
        }
      } else {
        if character == "\"" { inString = true }
        stripped.append(character)
      }
    }
    return stripped
  }
}
