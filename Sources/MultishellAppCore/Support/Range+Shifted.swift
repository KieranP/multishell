extension Range<Int> {
  public func shifted(by offset: Int) -> Self { (lowerBound + offset)..<(upperBound + offset) }
}
