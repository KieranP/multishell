import Foundation
import TestScratch

/// A directory of fake executables, for detection on a fake PATH: a new
/// temp directory, or `directory`, made where it is missing.
@discardableResult
func fakeBin(_ names: [String], in directory: URL? = nil) throws -> URL {
  let directory = try directory ?? Scratch.directory("bin")
  try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
  for name in names {
    try Scratch.script("exit 0", at: directory.appendingPathComponent(name))
  }
  return directory
}
