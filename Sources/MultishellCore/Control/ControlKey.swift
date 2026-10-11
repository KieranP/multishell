/// One key `multishell panes key` presses, as `ctrl-c` or `shift-tab` spell it.
public struct ControlKey: Codable, Equatable, Sendable {
  public enum Modifier: String, Codable, Sendable {
    case command = "cmd"
    case control = "ctrl"
    case option = "alt"
    case shift
  }

  /// The keys with a name rather than a character.
  public static let names: [String] =
    [
      "enter", "escape", "tab", "backspace", "delete", "space", "up", "down", "left", "right",
      "home", "end", "pageup", "pagedown",
    ] + (1...12).map { "f\($0)" }

  /// The characters a key may be: a US keyboard's unshifted ones.
  static let characters = Set("abcdefghijklmnopqrstuvwxyz0123456789-=[];',./`\\")

  /// A name from `names`, or one of `characters`.
  public let key: String
  public let modifiers: [Modifier]

  /// Decoding skips `init?(parsing:)`, so a request from a client other than
  /// the helper is checked with this before any key is pressed.
  public var isKnown: Bool { Self.isKnown(key) }

  /// `nil` for a key or modifier this does not know, or one given twice, so a
  /// typo is caught here. A capital on its own is that letter with Shift.
  public init?(parsing text: String) {
    var parts = text.split(separator: "-", omittingEmptySubsequences: false).map(String.init)
    // A dash on its own, or after one, is the minus key: `-`, `ctrl--`.
    if text == "-" {
      parts = ["-"]
    } else if text.hasSuffix("--") {
      parts = Array(parts.dropLast(2)) + ["-"]
    }
    guard let typed = parts.last else { return nil }
    let isCapital = typed.count == 1 && typed.first?.isUppercase == true
    let key = typed.lowercased()
    guard Self.isKnown(key) else { return nil }
    var modifiers: [Modifier] = []
    for part in parts.dropLast() {
      guard let modifier = Modifier(rawValue: part.lowercased()), !modifiers.contains(modifier)
      else { return nil }
      modifiers.append(modifier)
    }
    // After a modifier the case is how it was typed, so `Ctrl-C` interrupts.
    if isCapital, modifiers.isEmpty { modifiers.append(.shift) }
    self.key = key
    self.modifiers = modifiers
  }

  private static func isKnown(_ key: String) -> Bool {
    names.contains(key) || (key.count == 1 && key.first.map(characters.contains) == true)
  }
}
