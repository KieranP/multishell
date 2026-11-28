import Foundation

/// The state file's link stopped resolving after launch read it: its folder moved
/// or its volume went. Nothing is saved until the target is back.
public struct GoneStateFileLinkTarget: Error {
  public let fileURL: URL
  public let target: URL
}
