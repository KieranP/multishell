import Foundation
import TestScratch

@testable import MultishellGitKit

/// A script named as `gh` or `circleci`, so the run log names it alike. Each run
/// writes its arguments, then the runner's variables, to a file of its own.
struct FakeTool {
  /// One file per run: two runs at once appending to one file lost a line
  /// under the full suite's load.
  private static let callFilePrefix = "call."

  let directory: URL
  let executable: URL
  let runLog = GitRunLog()

  /// Oldest run first.
  var calls: [FakeToolCall] {
    let files =
      (try? FileManager.default.contentsOfDirectory(
        at: directory,
        includingPropertiesForKeys: [.contentModificationDateKey],
      )) ?? []
    return
      files
      .filter { $0.lastPathComponent.hasPrefix(Self.callFilePrefix) }
      .sorted { modified($0) < modified($1) }
      .compactMap { try? String(contentsOf: $0, encoding: .utf8) }
      .compactMap(Self.call(recordedAs:))
  }

  init(named name: String, _ body: String) throws {
    directory = try Scratch.directory("faketool")
    let calls = directory.appendingPathComponent(Self.callFilePrefix).path
    executable = try Scratch.script(
      """
      printf '%s\\nPATH=%s GH_PROMPT_DISABLED=%s NO_COLOR=%s GH_TOKEN=%s\\n' \\
        "$*" "$PATH" "$GH_PROMPT_DISABLED" "$NO_COLOR" "$GH_TOKEN" > "\(calls)$$"
      \(body)
      """,
      at: directory.appendingPathComponent(name),
    )
  }

  /// Empty lines count: a run given no arguments writes an empty first line.
  private static func call(recordedAs text: String) -> FakeToolCall? {
    let lines = text.split(separator: "\n", omittingEmptySubsequences: false)
    guard lines.count >= 2 else { return nil }
    return FakeToolCall(arguments: String(lines[0]), variables: String(lines[1]))
  }

  func tearDown() {
    Scratch.remove(directory)
  }

  private func modified(_ file: URL) -> Date {
    (try? file.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate
      ?? .distantPast
  }
}
