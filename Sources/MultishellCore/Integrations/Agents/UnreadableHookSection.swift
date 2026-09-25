import Foundation

/// `hooks` holds something other than an object of events: a list, or a
/// string. Refused rather than replaced, this being unable to put it back.
public struct UnreadableHookSection: Error, CustomStringConvertible {
  public let file: URL

  init(file: URL) { self.file = file }

  public var description: String {
    "\(file.path) holds something under hooks that Multishell does not recognise."
  }
}
