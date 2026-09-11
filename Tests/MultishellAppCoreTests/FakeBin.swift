import Foundation
import TestScratch

/// A temp directory of fake executables, for detection on a fake PATH.
func fakeBin(_ names: [String]) throws -> URL {
  let directory = try Scratch.directory("bin")
  for name in names {
    try Scratch.script("exit 0", at: directory.appendingPathComponent(name))
  }
  return directory
}
