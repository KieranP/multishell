extension String {
  /// Itself, or `nil` where empty. A blank string is kept; `trimmedOrNil`
  /// drops that too.
  var nonEmpty: String? { isEmpty ? nil : self }
}
