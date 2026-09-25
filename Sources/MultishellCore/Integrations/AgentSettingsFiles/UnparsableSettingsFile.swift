import Foundation

/// Not JSON this can read, a comment or trailing comma being the usual
/// reason. Parsing loosely and writing back strictly would lose them.
public struct UnparsableSettingsFile: Error, CustomStringConvertible {
  public let file: URL

  init(file: URL) { self.file = file }

  public var description: String {
    "\(file.path) is not plain JSON, so Multishell will not rewrite it."
  }
}
