import Foundation
import TestScratch
import Testing

@testable import MultishellCore

/// The plugin is 70 lines of state that no Swift test can reach: it keeps its
/// own roster of child sessions and decides what the helper is told. These run
/// it under node with `spawn` replaced, and read the argument lists back.
@Suite(.serialized, .enabled(if: openCodeNode != nil))
struct OpenCodePluginRunTests {
  /// A step handed to the driver: a hook by name, with whatever OpenCode
  /// passes it.
  private struct Step: Encodable {
    var hook: String
    var input: [String: String]?
    var output: [String: [String: String]]?
    var event: [String: AnyEncodable]?

    static func message(session: String?, inSecondArgument: Bool = false) -> Step {
      guard let session else { return Step(hook: "chat.message", input: [:]) }
      return inSecondArgument
        ? Step(hook: "chat.message", input: [:], output: ["message": ["sessionID": session]])
        : Step(hook: "chat.message", input: ["sessionID": session])
    }

    static func tool(session: String) -> Step {
      Step(hook: "tool.execute.before", input: ["sessionID": session])
    }

    static func event(_ type: String, _ properties: [String: AnyEncodable]) -> Step {
      Step(
        hook: "event", event: ["type": AnyEncodable(type), "properties": AnyEncodable(properties)])
    }

    static func created(child: String, of parent: String, agent: String) -> Step {
      event(
        "session.created",
        ["info": AnyEncodable(["id": parent + "/" + child, "parentID": parent, "agent": agent])])
    }

    static func idle(_ session: String) -> Step {
      event("session.idle", ["sessionID": AnyEncodable(session)])
    }

    static func busy(_ session: String) -> Step {
      event(
        "session.status",
        ["sessionID": AnyEncodable(session), "status": AnyEncodable(["type": "busy"])])
    }

    static func asked(_ session: String, tool: String) -> Step {
      event("permission.asked", ["sessionID": AnyEncodable(session), "tool": AnyEncodable(tool)])
    }
  }

  /// Enough of an encoder for the shapes OpenCode hands a plugin: strings and
  /// dictionaries of them, nested.
  private struct AnyEncodable: Encodable {
    private let encode: (Encoder) throws -> Void

    init(_ value: String) { encode = { try value.encode(to: $0) } }
    init(_ value: [String: String]) { encode = { try value.encode(to: $0) } }
    init(_ value: [String: AnyEncodable]) { encode = { try value.encode(to: $0) } }

    func encode(to encoder: Encoder) throws { try encode(encoder) }
  }

  /// What the helper was called with, one list per report, in order.
  private func reports(of steps: [Step]) throws -> [[String]] {
    let node = try #require(openCodeNode)
    let directory = Scratch.path("opencode-plugin")
    defer { try? FileManager.default.removeItem(at: directory) }
    let plugin = directory.appendingPathComponent("multishell.js")
    try AgentHooks.openCode.install(into: plugin, helper: "$HOME/bin/multishell")
    try Self.driver.write(
      to: directory.appendingPathComponent("drive.mjs"), atomically: true, encoding: .utf8)
    try Self.stub.write(
      to: directory.appendingPathComponent("stub.mjs"), atomically: true, encoding: .utf8)
    try Self.hooks.write(
      to: directory.appendingPathComponent("hooks.mjs"), atomically: true, encoding: .utf8)
    try Self.register.write(
      to: directory.appendingPathComponent("register.mjs"), atomically: true, encoding: .utf8)

    let script = String(decoding: try JSONEncoder().encode(steps), as: UTF8.self)
    let process = Process()
    process.executableURL = node
    process.arguments = ["--import", "./register.mjs", "./drive.mjs", script]
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
    return String(decoding: printed, as: UTF8.self).split(separator: "\n").compactMap {
      try? JSONDecoder().decode([String].self, from: Data($0.utf8))
    }
  }

  /// What a report says about a worker, as the chip reads it: the state, the
  /// phase, and the kind.
  private func said(_ report: [String]) -> String {
    var parts = [report.count > 1 ? report[1] : ""]
    for flag in ["--subagent-phase", "--subagent-type", "--new-turn", "--message"] {
      if let index = report.firstIndex(of: flag), index + 1 < report.count {
        parts.append(report[index + 1])
      }
    }
    return parts.joined(separator: " ")
  }

  @Test func aPromptInTheParentStartsATurnAndOneInAChildIsItsWork() throws {
    let out = try reports(of: [
      .message(session: "parent"),
      .created(child: "a", of: "parent", agent: "Explore"),
      .tool(session: "parent/a"),
      .idle("parent/a"),
      .idle("parent"),
    ])
    #expect(
      out.map(said) == [
        "running true", "running started Explore", "running working Explore",
        "running ended Explore", "done",
      ])
  }

  /// The one report that empties the roster. OpenCode hands `chat.message`
  /// the message as its second argument, so a session named only there still
  /// has to be read, or every child's message starts the parent's turn.
  @Test func aChildsMessageInTheSecondArgumentStartsNoTurnOfTheParents() throws {
    let out = try reports(of: [
      .message(session: "parent"),
      .created(child: "a", of: "parent", agent: "Explore"),
      .message(session: "parent/a", inSecondArgument: true),
      .idle("parent"),
      .idle("parent/a"),
    ])
    #expect(
      out.map(said) == [
        "running true", "running started Explore", "running working Explore", "done",
        "running ended Explore",
      ],
      "the child's message is its work, not a turn of the parent's")
  }

  /// A hook that names no session at all: before the roster it cost nothing,
  /// and it must still cost nothing rather than clear what is out.
  @Test func aMessageNamingNoSessionStartsNoTurn() throws {
    let out = try reports(of: [
      .message(session: "parent"),
      .created(child: "a", of: "parent", agent: "Explore"),
      .message(session: nil),
      .idle("parent/a"),
    ])
    #expect(
      out.map(said) == [
        "running true", "running started Explore", "running", "running ended Explore",
      ])
  }

  /// A prompt inside a child is that worker's, not the pane's, and carries
  /// what is being asked for.
  @Test func aPermissionAskedInsideAChildIsThatWorkersPrompt() throws {
    let out = try reports(of: [
      .created(child: "a", of: "parent", agent: "Plan"),
      .asked("parent/a", tool: "Bash"),
    ])
    #expect(out.map(said) == ["running started Plan", "attention working Plan Bash"])
  }

  /// A child's id outlives its end, so a late event of its own is not read as
  /// the parent's Done.
  @Test func anEventAfterAChildHasEndedReportsNothing() throws {
    let out = try reports(of: [
      .created(child: "a", of: "parent", agent: "Explore"),
      .idle("parent/a"),
      .idle("parent/a"),
      .tool(session: "parent/a"),
    ])
    #expect(out.map(said) == ["running started Explore", "running ended Explore"])
  }

  /// A child going busy and idle over and over holds one place among the ids
  /// kept past an end, so it cannot push another child's out and have that
  /// child's late event read as the parent's Done.
  @Test func aChildCyclingBusyAndIdleKeepsOnePlaceAmongTheEndedIds() throws {
    var steps: [Step] = [
      .created(child: "a", of: "parent", agent: "Explore"),
      .created(child: "b", of: "parent", agent: "Plan"),
      .idle("parent/b"),
    ]
    for _ in 0..<70 {
      steps.append(.busy("parent/a"))
      steps.append(.idle("parent/a"))
    }
    steps.append(.idle("parent/b"))

    let out = try reports(of: steps).map(said)
    #expect(out.last == "running ended Explore", "b's late idle says nothing")
    #expect(!out.contains("done"), "and is not read as the parent's Done")
  }

  private static let register = """
    import { register } from "node:module"
    register("./hooks.mjs", import.meta.url)

    """

  private static let hooks = """
    export async function resolve(specifier, context, next) {
      if (specifier === "node:child_process") {
        return { url: new URL("./stub.mjs", import.meta.url).href, shortCircuit: true }
      }
      return next(specifier, context)
    }

    """

  private static let stub = """
    export const spawn = (command, args) => {
      process.stdout.write(JSON.stringify(args) + "\\n")
      return { on: () => {}, unref: () => {} }
    }

    """

  private static let driver = """
    import { MultishellPlugin } from "./multishell.js"

    const plugin = await MultishellPlugin({ directory: "/w", worktree: "/w" })
    for (const step of JSON.parse(process.argv[2])) {
      if (step.hook === "event") await plugin.event({ event: step.event })
      else await plugin[step.hook](step.input, step.output)
    }

    """
}

/// Node as the suite's trait reads it, before the type exists.
private let openCodeNode: URL? = {
  ["/usr/local/bin/node", "/opt/homebrew/bin/node", "/usr/bin/node"]
    .map(URL.init(fileURLWithPath:))
    .first { FileManager.default.isExecutableFile(atPath: $0.path) }
    ?? which("node")
}()

private func which(_ name: String) -> URL? {
  let paths = ProcessInfo.processInfo.environment["PATH"]?.split(separator: ":") ?? []
  return paths.map { URL(fileURLWithPath: String($0)).appendingPathComponent(name) }
    .first { FileManager.default.isExecutableFile(atPath: $0.path) }
}
