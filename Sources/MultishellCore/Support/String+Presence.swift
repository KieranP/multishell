extension String {
  /// Itself, or `nil` where empty. Unlike Ruby's, a blank string is kept;
  /// `trimmedOrNil` drops that too.
  var presence: String? { isEmpty ? nil : self }
}
