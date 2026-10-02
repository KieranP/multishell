import Foundation
import TestScratch

/// Where a `state.json` would go, alone in a scratch directory not yet made, which the
/// caller removes.
func scratchStatePath(_ tag: String = "state") -> URL {
  Scratch.path(tag).appendingPathComponent("state.json")
}

/// A `state.json` holding `json`, alone in a scratch directory the caller removes.
func scratchStateFile(holding json: String) throws -> URL {
  let directory = try Scratch.directory("state")
  let file = directory.appendingPathComponent("state.json")
  try Data(json.utf8).write(to: file)
  return file
}
