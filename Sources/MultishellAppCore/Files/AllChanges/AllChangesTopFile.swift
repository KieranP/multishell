/// The file at the top of an All changes tab's view: what the Changes list
/// lights, and whether its header has scrolled away so a sticky copy shows.
public struct AllChangesTopFile: Equatable, Sendable {
  public let path: String
  public let isHeaderScrolledPast: Bool
  /// How far the next file's header, scrolling up into the sticky copy,
  /// pushes it up and out of the way.
  public let pushedUp: Double

  public init(path: String, isHeaderScrolledPast: Bool) {
    self.path = path
    self.isHeaderScrolledPast = isHeaderScrolledPast
    pushedUp = 0
  }

  /// From where the file's header bar and the next file's start in the
  /// document, the scroll, and the bar's height.
  public init(
    path: String,
    headerBarTop: Double?,
    nextHeaderBarTop: Double?,
    scrolledTo: Double,
    barHeight: Double,
  ) {
    self.path = path
    isHeaderScrolledPast = headerBarTop.map { scrolledTo > $0 } ?? false
    guard isHeaderScrolledPast, let nextHeaderBarTop else {
      pushedUp = 0
      return
    }
    pushedUp = max(0, barHeight - (nextHeaderBarTop - scrolledTo))
  }
}
