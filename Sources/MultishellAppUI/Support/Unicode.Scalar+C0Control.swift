extension Unicode.Scalar {
  /// The controls below space, which Control with a key types.
  var isC0Control: Bool { value < 0x20 }
}
