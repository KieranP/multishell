import Foundation

/// The state file is a link to a file that is not there, on a volume not
/// mounted or a branch without it. Nothing is saved through it while it dangles.
public struct DanglingStateFileLink: Error {
  public let fileURL: URL
  public let target: URL
}
