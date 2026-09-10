/// The few English forms built by hand, for the dialogs and the board.
enum Wording {
  /// "1 open terminal", "3 open terminals". Only for nouns that pluralise
  /// with an s.
  static func count(_ number: Int, _ noun: String) -> String {
    "\(number) \(noun)\(number == 1 ? "" : "s")"
  }
}
