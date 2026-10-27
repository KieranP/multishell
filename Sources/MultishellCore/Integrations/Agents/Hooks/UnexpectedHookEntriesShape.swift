import Foundation

/// One event holds something other than the documented list of hooks. Not
/// written over, this being unable to put it back.
public struct UnexpectedHookEntriesShape: Error, CustomStringConvertible {
  public let file: URL
  /// The key the events sit under: `hooks`, or Antigravity's named set.
  public let section: String
  public let event: String

  public var description: String {
    "\(file.path) holds something under \(section).\(event) that Multishell does not recognise."
  }
}
