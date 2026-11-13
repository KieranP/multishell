/// A new branch's name an existing branch holds, or one git keeps the other
/// as a folder of. Raised before the pre-create hook, as `InvalidBranchName` is.
public struct BranchNameTaken: Error, CustomStringConvertible {
  public let branch: String
  /// The existing branch: `branch` itself, or one above or below it.
  public let existing: String

  /// The log's form. What the user is shown is `PresentedError`'s.
  public var description: String { "the branch \(existing) leaves no room for \(branch)" }
}
