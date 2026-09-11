/// The few English forms built by hand, for the dialogs, the board and the
/// sidebar.
public enum Wording {
  /// "1 open terminal", "3 open terminals". Only for nouns that pluralise
  /// with an s.
  public static func count(_ number: Int, _ noun: String) -> String {
    "\(number) \(noun)\(number == 1 ? "" : "s")"
  }
}
