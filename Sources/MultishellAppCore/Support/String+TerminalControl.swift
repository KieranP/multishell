extension String {
  /// Whether typing this into a terminal could act rather than show: a C0 or
  /// C1 control, or DEL. A newline in a pasted path would press Return.
  var holdsTerminalControl: Bool {
    unicodeScalars.contains { scalar in
      scalar.value < 0x20 || scalar.value == 0x7f || (0x80...0x9f).contains(scalar.value)
    }
  }
}
