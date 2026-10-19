/// Text with its character references decoded, and for each of its UTF-16 units
/// the source offset it came from, the source's length last.
struct DecodedText {
  let text: String
  let sourceOffsets: [Int]

  /// A decoded range over the whole references it came from.
  func sourceRange(of range: Range<Int>) -> Range<Int> {
    sourceOffsets[range.lowerBound]..<sourceOffsets[range.upperBound]
  }
}
