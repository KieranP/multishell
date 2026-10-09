// Declared order is the raw value, the palette index.
// swiftlint:disable sorted_enum_cases
/// The eight normal ANSI colours by name, each its slot in `Theme.ansi`.
public enum ANSIColor: Int, Sendable {
  case black, red, green, yellow, blue, magenta, cyan, white
}
// swiftlint:enable sorted_enum_cases
