extension String {
  /// `//` and `/* */` comments stripped outside strings, where a URL's `//` is text.
  /// By scalar: a combining mark after a quote joins it into one `Character`.
  var withoutJSONComments: String {
    var stripped = Self.UnicodeScalarView()
    var scalars = unicodeScalars.makeIterator()
    var inString = false
    var pending = scalars.next()
    while let scalar = pending {
      pending = scalars.next()
      if inString {
        stripped.append(scalar)
        if scalar == "\\", let escaped = pending {
          stripped.append(escaped)
          pending = scalars.next()
        } else if scalar == "\"" {
          inString = false
        }
      } else if scalar == "/", pending == "/" {
        while let skipped = pending, skipped != "\n", skipped != "\r" { pending = scalars.next() }
      } else if scalar == "/", pending == "*" {
        pending = scalars.next()
        var previous: Unicode.Scalar?
        while let skipped = pending {
          pending = scalars.next()
          if previous == "*", skipped == "/" { break }
          previous = skipped
        }
      } else {
        if scalar == "\"" { inString = true }
        stripped.append(scalar)
      }
    }
    return String(stripped)
  }
}
