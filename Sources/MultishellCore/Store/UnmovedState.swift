import Foundation

/// Unreadable and unmovable both, so it still stands where a save would land.
/// Nothing may write that path; see `WorkspaceStore.refusesToSave`.
public struct UnmovedState: Error {
  public let file: URL
  public let underlying: any Error
  public let move: any Error

  init(file: URL, underlying: any Error, move: any Error) {
    self.file = file
    self.underlying = underlying
    self.move = move
  }
}
