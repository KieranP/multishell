import Foundation
import MultishellCore

extension Helper {
  /// The words before the first option, then any after `--`, which ends the
  /// options so a word may start with a dash; a lone `-` is a word, as in POSIX.
  static func positionals(
    _ arguments: ArraySlice<String>
  ) -> (words: [String], optionWords: ArraySlice<String>) {
    let end = arguments.firstIndex(of: "--")
    let head = arguments[..<(end ?? arguments.endIndex)]
    let firstOption = head.firstIndex { $0.hasPrefix("-") && $0 != "-" } ?? head.endIndex
    let afterEnd = end.map { arguments[($0 + 1)...] } ?? []
    return (Array(head[..<firstOption]) + afterEnd, head[firstOption...])
  }

  /// Relative to where this runs, as a shell user means it: the folder to add
  /// as a project, or the file a screenshot is written to.
  static func absolutePath(_ path: String?) -> String {
    let here = URL(fileURLWithPath: FileManager.default.currentDirectoryPath, isDirectory: true)
    return URL(fileURLWithPath: path ?? ".", isDirectory: true, relativeTo: here)
      .standardizedFileURL.path
  }

  static func noOptions(_ optionWords: ArraySlice<String>, topic: String) throws {
    _ = try CommandOptions(optionWords, valued: [], topic: topic)
  }

  /// Whether `--force` is the one option given.
  static func isForced(_ optionWords: ArraySlice<String>, topic: String) throws -> Bool {
    try CommandOptions(optionWords, valued: [], flags: ["force"], topic: topic).has("force")
  }

  /// A tab's or pane's id, as `tabs list` prints them.
  static func tabOrPaneID(_ text: String, topic: String) throws -> UUID {
    guard let id = UUID(uuidString: text) else {
      throw UsageError("not an id: \(text); `multishell tabs list` names them", topic: topic)
    }
    return id
  }

  static func projectID(_ text: String, topic: String) throws -> String {
    guard ControlID.isProject(text) else {
      throw UsageError(
        "not a project id: \(text); `multishell projects list` names them",
        topic: topic,
      )
    }
    return text
  }

  static func worktreeID(_ text: String, topic: String) throws -> String {
    guard ControlID.isWorktree(text) else {
      throw UsageError(
        "not a worktree id: \(text); `multishell worktrees list` names them",
        topic: topic,
      )
    }
    return text
  }

  /// What comes before `--` and the command after it, `nil` where there is no `--`.
  static func splitAtDoubleDash(
    _ arguments: ArraySlice<String>
  ) -> (head: ArraySlice<String>, command: ArraySlice<String>?) {
    guard let marker = arguments.firstIndex(of: "--") else { return (arguments, nil) }
    return (arguments[..<marker], arguments[(marker + 1)...])
  }

  /// A rename's second word; none, or an empty one, hands the name back.
  static func givenName(in words: [String]) -> String? {
    words.count == 2 && !words[1].isEmpty ? words[1] : nil
  }
}
