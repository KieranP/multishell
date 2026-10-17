/// What the view lays out: `string` with each character TextKit 2 breaks a
/// line at drawn as its control picture, one UTF-16 unit for one.
extension DiffDisplayText {
  /// git splits lines at `\n` alone, so these sit inside one row.
  private static let breakPictures: [Unicode.Scalar: Unicode.Scalar] = [
    "\r": "\u{240D}", "\u{0B}": "\u{240B}", "\u{0C}": "\u{240C}", "\u{85}": "\u{2424}",
    "\u{2028}": "\u{23CE}", "\u{2029}": "\u{00B6}",
  ]
  /// `breakPictures`' keys by UTF-16 unit: a dictionary lookup per scalar took
  /// 18 ms over 1 MiB, an index into this 2 ms.
  private static let isBreakUnit: [Bool] = {
    var table = [Bool](
      repeating: false,
      count: Int(breakPictures.keys.map(\.value).max() ?? 0) + 1,
    )
    for scalar in breakPictures.keys { table[Int(scalar.value)] = true }
    return table
  }()

  /// Offsets, find and copy all still read `string`, which this matches unit
  /// for unit.
  public var drawnString: String {
    let table = Self.isBreakUnit
    guard string.utf16.contains(where: { Int($0) < table.count && table[Int($0)] }) else {
      return string
    }
    var drawn = String.UnicodeScalarView()
    for scalar in string.unicodeScalars { drawn.append(Self.breakPictures[scalar] ?? scalar) }
    return String(drawn)
  }
}
