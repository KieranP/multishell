/// A quoted string read a unit at a time, its escapes included.
struct OpenString {
  private var quote: UInt16?
  private var isEscaped = false

  var isOpen: Bool { quote != nil }

  /// Opens on `unit` when closed; when open, closes on its quote unescaped.
  mutating func read(_ unit: UInt16) {
    guard let open = quote else {
      quote = unit
      return
    }
    if isEscaped {
      isEscaped = false
    } else if unit == ASCIIUnits.backslash {
      isEscaped = true
    } else if unit == open {
      quote = nil
    }
  }
}
