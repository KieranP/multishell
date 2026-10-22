extension ScannedBlockHead {
  func lastNonWhitespace(before end: Int) -> Int? {
    units[..<end].lastIndex { !ASCIIUnits.whitespace.contains($0) }
  }

  func firstNonWhitespace(from start: Int) -> Int? {
    units[start...].firstIndex { !ASCIIUnits.whitespace.contains($0) }
  }
}
