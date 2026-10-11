import Foundation
import MultishellCore

extension Helper {
  /// What `debug log` covers unless told, in `log show`'s own spelling.
  private static let logSpan = "5m"
  private static let logTool = URL(fileURLWithPath: "/usr/bin/log")

  /// `log show`, or `log stream` with `--follow`, narrowed to the running app's
  /// own lines by its bundle identifier, its subsystem.
  static func runDebugLog(
    _ arguments: ArraySlice<String>,
    environment: [String: String],
  ) throws -> Int32 {
    let topic = ControlCommand.debug.rawValue
    let options = try CommandOptions(
      arguments,
      valued: ["since"],
      flags: ["follow", "plain"],
      topic: topic,
    )
    guard !options.has("follow") || options["since"] == nil else {
      throw UsageError("--since is for a past span; --follow reads from now", topic: topic)
    }
    let span = options["since"] ?? logSpan
    guard span.range(of: #"^[0-9]+[smhd]$"#, options: .regularExpression) != nil else {
      throw UsageError("--since takes a span such as 30s, 5m, 2h or 1d", topic: topic)
    }
    guard let subsystem = ownApp.flatMap({ Bundle(url: $0)?.bundleIdentifier }) else {
      printError("this helper is in no app bundle, so there is no app log to read")
      return 1
    }
    let info = try output(of: .info, environment: environment) ?? ""
    let fields = jsonValue(info) as? [String: Any]
    guard let pid = fields?["pid"] as? Int32 else { throw ControlUnanswered.silent }
    let tool = Process()
    tool.executableURL = logTool
    tool.arguments = logArguments(
      pid: pid,
      subsystem: subsystem,
      span: span,
      follows: options.has("follow"),
      isPlain: options.has("plain"),
    )
    let lines = Pipe()
    if !options.has("plain") { tool.standardOutput = lines }
    try tool.run()
    if !options.has("plain") {
      try forEachJSONLine(in: lines.fileHandleForReading) { line in
        print(line)
        fflush(stdout)
      }
    }
    tool.waitUntilExit()
    return tool.terminationStatus
  }

  static func logArguments(
    pid: Int32,
    subsystem: String,
    span: String,
    follows: Bool,
    isPlain: Bool = false,
  ) -> [String] {
    let predicate = #"subsystem == "\#(subsystem)" AND processID == \#(pid)"#
    let style = ["--style", isPlain ? "compact" : "ndjson", "--predicate", predicate]
    return follows
      ? ["stream", "--level", "debug"] + style
      : ["show", "--last", span, "--info", "--debug"] + style
  }

  /// As they come, for `--follow`: `log` heads its stream with a line of
  /// prose, which is no JSON and is left out.
  static func forEachJSONLine(in handle: FileHandle, _ body: (String) -> Void) throws {
    var pending = Data()
    while let chunk = try handle.read(upToCount: 4_096), !chunk.isEmpty {
      pending.append(chunk)
      while let newline = pending.firstIndex(of: UInt8(ascii: "\n")) {
        let line = String(decoding: pending[..<newline], as: UTF8.self)
        pending.removeSubrange(...newline)
        if line.hasPrefix("{") { body(line) }
      }
    }
    let unterminated = String(decoding: pending, as: UTF8.self)
    if unterminated.hasPrefix("{") { body(unterminated) }
  }
}
