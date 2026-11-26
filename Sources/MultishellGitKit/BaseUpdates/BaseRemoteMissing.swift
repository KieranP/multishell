/// A remote-tracking base whose remote git no longer lists, a rename or removal
/// having left its refs: updating from it would take in a stale copy unfetched.
public struct BaseRemoteMissing: Error, CustomStringConvertible {
  /// The base as git prints it short, `old/main`.
  public let base: String

  /// The log's form. What the user is shown is `PresentedError`'s.
  public var description: String { "no remote lists \(base)" }
}
