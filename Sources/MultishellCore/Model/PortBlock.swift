/// The run of ports each worktree's servers take, numbered from the starting
/// port; see Docs/design/worktrees.md.
public enum PortBlock {
  public static let highestPort = 65_535
  /// Below it are the well-known ports, which system services claim.
  private static let lowestStart = 1024
  public static let starts = lowestStart...highestPort
  /// Up to one block taking every port from the lowest start.
  public static let sizes = 1...(highestPort - lowestStart + 1)
  /// Every block some start and size could fit, the last at size one.
  static let indices = 0...(highestPort - lowestStart)
  static let defaultStart = 3000
  static let defaultSize = 10

  /// `nil` where the block would end past `highestPort`.
  static func firstPort(ofBlock index: Int, start: Int, size: Int) -> Int? {
    guard indices.contains(index) else { return nil }
    let first = start + index * size
    return first + size - 1 <= highestPort ? first : nil
  }
}
