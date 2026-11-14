/// The file at the top of an All changes tab's view: what the Changes list
/// lights, and whether its header has scrolled away so a sticky copy shows.
public struct AllChangesTopFile: Equatable, Sendable {
  public let path: String
  public let isHeaderScrolledPast: Bool

  public init(path: String, isHeaderScrolledPast: Bool) {
    self.path = path
    self.isHeaderScrolledPast = isHeaderScrolledPast
  }
}
