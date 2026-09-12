import Foundation

/// The file's top level is not a JSON object, so there is nowhere to put a
/// `hooks` key. Refused rather than replaced.
public struct UnexpectedSettingsShape: Error, CustomStringConvertible {
  public let file: URL

  public init(file: URL) { self.file = file }

  public var description: String {
    "\(file.path) is not a JSON object, so Multishell will not rewrite it."
  }
}

/// One event holds something other than the documented list of hooks. Not
/// written over, this being unable to put it back.
public struct UnreadableHookEntries: Error, CustomStringConvertible {
  public let file: URL
  public let event: String

  public init(file: URL, event: String) {
    self.file = file
    self.event = event
  }

  public var description: String {
    "\(file.path) holds something under hooks.\(event) that Multishell does not recognise."
  }
}

/// `hooks` holds something other than an object of events: a list, or a
/// string. Refused rather than replaced, this being unable to put it back.
public struct UnreadableHookSection: Error, CustomStringConvertible {
  public let file: URL

  public init(file: URL) { self.file = file }

  public var description: String {
    "\(file.path) holds something under hooks that Multishell does not recognise."
  }
}

/// Not JSON this can read, a comment or trailing comma being the usual
/// reason. Parsing loosely and writing back strictly would lose them.
public struct UnparsableSettingsFile: Error, CustomStringConvertible {
  public let file: URL

  public init(file: URL) { self.file = file }

  public var description: String {
    "\(file.path) is not plain JSON, so Multishell will not rewrite it."
  }
}
