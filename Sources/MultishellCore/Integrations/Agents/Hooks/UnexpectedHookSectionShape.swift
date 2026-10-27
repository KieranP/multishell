import Foundation

/// The section holds something other than an object of events. Refused
/// rather than replaced, this being unable to put it back.
public struct UnexpectedHookSectionShape: Error, CustomStringConvertible {
  public let file: URL
  public let section: String

  public var description: String {
    "\(file.path) holds something under \(section) that Multishell does not recognise."
  }
}
