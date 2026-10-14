import Foundation
import MultishellCore

extension Helper {
  static func readPane(
    _ id: UUID,
    _ optionWords: ArraySlice<String>,
    environment: [String: String],
  ) throws -> Int32 {
    let topic = ControlCommand.panes.rawValue
    let options = try CommandOptions(
      optionWords,
      valued: ["lines"],
      flags: ["scrollback", "plain"],
      topic: topic,
    )
    let text = try paneText(
      of: id,
      includingScrollback: options.has("scrollback"),
      lastLines: try options.count("lines"),
      environment: environment,
    )
    try options.has("plain") ? print(text) : printJSON(["pane": id.uuidString, "text": text])
    return 0
  }

  /// The pane as `panes show` prints it, and its fields, for a wait to read.
  static func describedPane(
    _ id: UUID,
    environment: [String: String],
    timeout: Duration?,
  ) throws -> (text: String?, fields: [String: Any]) {
    let text = try output(of: .describePane(id: id), environment: environment, timeout: timeout)
    return (text, jsonValue(text) as? [String: Any] ?? [:])
  }

  /// The pane's lines, the blank ones below the last written left out, as
  /// a screen not yet filled has.
  static func paneText(
    of id: UUID,
    includingScrollback: Bool,
    lastLines: Int?,
    environment: [String: String],
    timeout: Duration? = answerTimeout,
  ) throws -> String {
    let request = ControlRequest.readPane(id: id, includingScrollback: includingScrollback)
    let text = try output(of: request, environment: environment, timeout: timeout) ?? ""
    var lines = text.components(separatedBy: "\n")
    while lines.last?.trimmingCharacters(in: .whitespaces).isEmpty == true { lines.removeLast() }
    return lines.suffix(lastLines ?? lines.count).joined(separator: "\n")
  }
}
