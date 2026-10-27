extension String {
  /// The first line holding any text: all a tooltip or a settings row shows
  /// of what a tool said.
  var firstLine: String {
    split(whereSeparator: \.isNewline).first.map(Self.init) ?? ""
  }
}
