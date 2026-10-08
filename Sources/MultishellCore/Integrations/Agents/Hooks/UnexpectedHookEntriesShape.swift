import Foundation

/// One event holds something other than the documented list of hooks. Not
/// written over, this being unable to put it back.
public struct UnexpectedHookEntriesShape: Error, CustomStringConvertible {
  public let file: URL
  public let event: String

  public var description: String {
    "\(file.path) holds something under hooks.\(event) that Multishell does not recognise."
  }
}
