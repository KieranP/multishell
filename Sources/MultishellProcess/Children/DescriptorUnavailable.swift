import Foundation

/// The process is out of file descriptors. Each watched worktree holds one
/// and each live shell several; a Finder-launched app starts with 256.
public struct DescriptorUnavailable: Error, CustomStringConvertible {
  public let code: Int32

  init(code: Int32) {
    self.code = code
  }

  /// The log's form. What the user is shown is `PresentedError`'s.
  public var description: String {
    "could not open a file descriptor: \(String(cString: strerror(code))) (\(code))"
  }
}
