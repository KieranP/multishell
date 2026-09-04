import Foundation

@testable import MultishellGitKit

/// A shell script standing in for `git`, for behaviour real git cannot be
/// made to show on demand: printing nothing, or being slow enough that
/// concurrency can be measured. The script sees its scratch directory as a
/// literal path, since `GitRunner` passes no environment.
struct FakeGit {
  let directory: URL
  let runner: GitRunner

  /// `body` runs with `$SCRATCH` set to the scratch directory.
  static func make(_ body: String) throws -> FakeGit {
    let directory = URL(fileURLWithPath: NSTemporaryDirectory())
      .appendingPathComponent("multishell-fakegit-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    let script = directory.appendingPathComponent("git")
    try "#!/bin/sh\nSCRATCH=\"\(directory.path)\"\n\(body)\n".write(
      to: script, atomically: true, encoding: .utf8)
    try FileManager.default.setAttributes(
      [.posixPermissions: 0o755], ofItemAtPath: script.path)
    return FakeGit(directory: directory, runner: try GitRunner(executable: script))
  }

  func tearDown() {
    try? FileManager.default.removeItem(at: directory)
  }
}
