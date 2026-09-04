import Foundation

extension String {
  /// `/Users/me/Work` becomes `~/Work`. Only a whole path component counts:
  /// `/Users/meg` is another user's home, not `~g`.
  func abbreviatingHomeDirectory(
    home: String = FileManager.default.homeDirectoryForCurrentUser.path
  ) -> String {
    if self == home { return "~" }
    guard hasPrefix(home + "/") else { return self }
    return "~" + dropFirst(home.count)
  }
}
