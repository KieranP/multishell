import Foundation

/// A process's name as a person would know it: an interpreter is named with
/// its script, as `node gemini`, since every Node agent is otherwise `node`.
enum ProcessLabel {
  private static let interpreters: Set<String> = [
    "bun", "deno", "node", "perl", "python", "python3", "ruby",
  ]

  /// `arguments` is read only for an interpreter: it costs two sysctls a process.
  static func of(name: String, arguments: @autoclosure () -> [String]?) -> String {
    guard interpreters.contains(name),
      let script = arguments()?.dropFirst().first(where: { !$0.hasPrefix("-") })
    else { return name }
    return "\(name) \(URL(fileURLWithPath: script).lastPathComponent)"
  }
}
