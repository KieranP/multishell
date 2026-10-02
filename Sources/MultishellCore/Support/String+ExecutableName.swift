import Foundation

extension String {
  /// The program a path or a command's first word names, as a tab or a picker
  /// shows it.
  public var executableName: String { URL(fileURLWithPath: self).lastPathComponent }
}
