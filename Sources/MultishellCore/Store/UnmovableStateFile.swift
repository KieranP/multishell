import Foundation

/// Unreadable and unmovable both, so it still stands where a save would land.
/// Nothing may write that path; see `WorkspaceStore.refusesToSave`.
public struct UnmovableStateFile: Error {
  public let file: URL
  public let underlying: any Error

  init(file: URL, underlying: any Error) {
    self.file = file
    self.underlying = underlying
  }
}
