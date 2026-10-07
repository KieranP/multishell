import Foundation

/// Unreadable and unmovable both, so it still stands where a save would land.
/// Nothing may write that path; see `WorkspaceStore.refusesToSave`.
public struct UnmovableStateFile: Error {
  public let fileURL: URL
  public let underlying: any Error

  init(fileURL: URL, underlying: any Error) {
    self.fileURL = fileURL
    self.underlying = underlying
  }
}
