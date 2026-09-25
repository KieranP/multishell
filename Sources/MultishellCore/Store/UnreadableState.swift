import Foundation

/// The words the user sees are the catalogue's, built by `PresentedError`;
/// see Docs/design/translation.md.
public struct UnreadableState: Error {
  public let backup: URL
  public let underlying: any Error

  init(backup: URL, underlying: any Error) {
    self.backup = backup
    self.underlying = underlying
  }
}
