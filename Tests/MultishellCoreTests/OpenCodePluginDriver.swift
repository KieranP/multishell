import Foundation
import TestScratch
import Testing

@testable import MultishellCore

/// Installs the plugin and runs it under node with `spawn` replaced, reading
/// back what the helper would have been called with.
protocol OpenCodePluginDriver {}

extension OpenCodePluginDriver {
  /// What the helper was called with, one list per report, in order.
  /// `sessions` is what the fake client answers a lookup with, by id.
  func reports(
    of steps: [OpenCodePluginStep], sessions: [String: [String: String]] = [:]
  ) throws -> [[String]] {
    try run(steps, sessions: sessions).reports
  }

  /// The reports, how many of the plugin's bounded waits on a lookup began,
  /// and every line in order, a helper's exit included.
  func run(
    _ steps: [OpenCodePluginStep], sessions: [String: [String: String]] = [:]
  ) throws -> (reports: [[String]], waits: Int, lines: [String]) {
    let node = try #require(openCodeNode)
    let directory = Scratch.path("opencode-plugin")
    defer { Scratch.remove(directory) }
    let plugin = directory.appendingPathComponent("multishell.js")
    try AgentHookCatalogue.openCode.install(into: plugin, helper: "$HOME/bin/multishell")
    try OpenCodePluginScripts.driver.write(
      to: directory.appendingPathComponent("drive.mjs"), atomically: true, encoding: .utf8)
    try OpenCodePluginScripts.stub.write(
      to: directory.appendingPathComponent("stub.mjs"), atomically: true, encoding: .utf8)
    try OpenCodePluginScripts.hooks.write(
      to: directory.appendingPathComponent("hooks.mjs"), atomically: true, encoding: .utf8)
    try OpenCodePluginScripts.register.write(
      to: directory.appendingPathComponent("register.mjs"), atomically: true, encoding: .utf8)

    let script = String(decoding: try JSONEncoder().encode(steps), as: UTF8.self)
    let known = String(decoding: try JSONEncoder().encode(sessions), as: UTF8.self)
    let process = Process()
    process.executableURL = node
    process.arguments = ["--import", "./register.mjs", "./drive.mjs", script, known]
    process.currentDirectoryURL = directory
    let out = Pipe()
    let errors = Pipe()
    process.standardOutput = out
    process.standardError = errors
    try process.run()
    let printed = out.fileHandleForReading.readDataToEndOfFile()
    let failed = errors.fileHandleForReading.readDataToEndOfFile()
    process.waitUntilExit()
    #expect(
      process.terminationStatus == 0,
      "node failed: \(String(decoding: failed, as: UTF8.self))")
    let lines = String(decoding: printed, as: UTF8.self).split(separator: "\n")
    let waits = lines.compactMap {
      try? JSONDecoder().decode([String: Int].self, from: Data($0.utf8))["waits"]
    }
    return (
      lines.compactMap { try? JSONDecoder().decode([String].self, from: Data($0.utf8)) },
      waits.last ?? 0, lines.map(String.init)
    )
  }

  /// What a report says about a worker, as the chip reads it: the state, the
  /// phase, and the kind.
  func chipSummary(of report: [String]) -> String {
    var parts = [report.count > 1 ? report[1] : ""]
    for flag in ["--subagent-phase", "--subagent-type", "--new-turn", "--message"] {
      if let index = report.firstIndex(of: flag), index + 1 < report.count {
        parts.append(report[index + 1])
      }
    }
    return parts.joined(separator: " ")
  }

  func flagValue(_ report: [String], _ flag: String) -> String? {
    report.firstIndex(of: flag).flatMap { $0 + 1 < report.count ? report[$0 + 1] : nil }
  }
}
