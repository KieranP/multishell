import Foundation

/// The file's top level is not a JSON object, so there is nowhere to put a
/// `hooks` key. Refused rather than replaced.
public struct UnexpectedSettingsShape: Error, CustomStringConvertible {
  public let file: URL

  init(file: URL) { self.file = file }

  public var description: String {
    "\(file.path) is not a JSON object, so Multishell will not rewrite it."
  }
}
