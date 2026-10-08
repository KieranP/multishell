extension Bool {
  /// A report's flag, encoded only where it is set so a report leaves the
  /// field out rather than sending the default.
  var trueOrNil: Bool? { self ? true : nil }
}
