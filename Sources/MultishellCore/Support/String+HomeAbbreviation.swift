import Foundation

extension String {
  /// `/Users/me/Work` becomes `~/Work`, or `$HOME/Work` for a hook line inside
  /// double quotes. Only a whole component counts: `/Users/meg` is not `~g`.
  public func abbreviatingHomeDirectory(
    home: String = FileManager.default.homeDirectoryForCurrentUser.path,
    as replacement: String = "~"
  ) -> String {
    if self == home { return replacement }
    guard hasPrefix(home + "/") else { return self }
    return replacement + dropFirst(home.count)
  }
}
