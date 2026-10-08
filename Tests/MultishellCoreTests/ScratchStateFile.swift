import Foundation
import TestScratch

/// A `state.json` holding `json`, alone in a scratch directory the caller removes.
func scratchStateFile(holding json: String) throws -> URL {
  let directory = try Scratch.directory("state")
  let file = directory.appendingPathComponent("state.json")
  try Data(json.utf8).write(to: file)
  return file
}
