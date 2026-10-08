extension Character {
  /// An ASCII letter or digit, `-` or `_`: safe in a file name and a socket path.
  var isPortableNameCharacter: Bool {
    isASCII && (isLetter || isNumber) || self == "-" || self == "_"
  }
}
