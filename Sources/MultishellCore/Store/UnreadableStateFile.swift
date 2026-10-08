import Foundation

/// The state file would not decode and was moved to `backup`. The words the
/// user sees are `PresentedError`'s; see Docs/design/translation.md.
public struct UnreadableStateFile: Error {
  public let backup: URL
  public let underlying: any Error
}
