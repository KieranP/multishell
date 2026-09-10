import Foundation

/// The file's top level is not a JSON object, so there is nowhere to put a
/// `hooks` key. Refused rather than replaced: whatever is there is the
/// user's.
public struct UnexpectedSettingsShape: Error, CustomStringConvertible {
  public let file: URL

  public init(file: URL) { self.file = file }

  public var description: String {
    "\(file.path) is not a JSON object, so Multishell will not rewrite it."
  }
}

/// One event holds something other than the list of hooks the agent
/// documents. Ours is not written over it, since whatever is there is the
/// user's and this cannot put it back.
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

/// Not JSON this can read at all, a comment or a trailing comma being the
/// usual reason. Refused rather than parsed loosely and written back
/// strictly, which would take the comments with it.
public struct UnparsableSettingsFile: Error, CustomStringConvertible {
  public let file: URL

  public init(file: URL) { self.file = file }

  public var description: String {
    "\(file.path) is not plain JSON, so Multishell will not rewrite it."
  }
}
