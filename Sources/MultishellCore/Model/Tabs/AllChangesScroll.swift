/// Where an All changes tab was left: the file at the top and its scroll within
/// that file, so a re-read that folds or adds rows above still lands there.
public struct AllChangesScroll: Codable, Hashable, Sendable {
  public let path: String
  public let scroll: FileTabScroll

  public init(path: String, scroll: FileTabScroll) {
    self.path = path
    self.scroll = scroll
  }
}
