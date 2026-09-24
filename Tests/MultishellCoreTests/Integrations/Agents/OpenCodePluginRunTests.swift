import Foundation
import TestScratch
import Testing

@testable import MultishellCore

/// The plugin's 70 lines of state are out of Swift's reach, so these run it under node
/// with `spawn` replaced and read the argument lists back.
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

    /// Long enough for a lookup the stub answers late to land.
    static var pause: Step { Step(hook: "pause") }

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

    static func asked(_ session: String, permission: String, pattern: String) -> Step {
      event(
        "permission.asked",
        [
          "sessionID": AnyEncodable(session), "permission": AnyEncodable(permission),
          "patterns": AnyEncodable([pattern]),
          "tool": AnyEncodable(["messageID": "message-1", "callID": "call-1"]),
        ])
    }
  }

  /// Enough of an encoder for the shapes OpenCode hands a plugin: strings and
  /// dictionaries of them, nested.
  private struct AnyEncodable: Encodable {
    private let encode: (Encoder) throws -> Void

    init(_ value: String) { encode = { try value.encode(to: $0) } }
    init(_ value: [String: String]) { encode = { try value.encode(to: $0) } }
    init(_ value: [String: AnyEncodable]) { encode = { try value.encode(to: $0) } }
    init(_ value: [String]) { encode = { try value.encode(to: $0) } }

    func encode(to encoder: Encoder) throws { try encode(encoder) }
  }

  /// What the helper was called with, one list per report, in order.
  /// `sessions` is what the fake client answers a lookup with, by id.
  private func reports(
    of steps: [Step], sessions: [String: [String: String]] = [:]
  ) throws -> [[String]] {
    try run(steps, sessions: sessions).reports
  }

  /// The reports, and how many of the plugin's bounded waits on a lookup began.
  private func run(
    _ steps: [Step], sessions: [String: [String: String]] = [:]
  ) throws -> (reports: [[String]], waits: Int) {
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
      waits.last ?? 0
    )
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

  @Test func aTurnsEndInBothSpellingsIsReportedOnce() throws {
    let idleStatus = Step.event(
      "session.status",
      ["sessionID": AnyEncodable("parent"), "status": AnyEncodable(["type": "idle"])])
    let out = try reports(of: [
      .message(session: "parent"), idleStatus, .idle("parent"),
      .message(session: "parent"), .idle("parent"), idleStatus,
    ])
    #expect(out.map(said) == ["running true", "done", "running true", "done"])
  }

  @Test func aParentTurnWithNoPromptStillEndsInADone() throws {
    let out = try reports(of: [
      .message(session: "parent"), .idle("parent"), .busy("parent"), .idle("parent"),
    ])
    #expect(out.map(said) == ["running true", "done", "done"])
  }

  /// OpenCode hands `chat.message` the message as its second argument, so a session named
  /// only there still has to be read, or every child's message starts the parent's turn.
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
      .asked("parent/a", permission: "bash", pattern: "echo hi"),
    ])
    #expect(out.map(said) == ["running started Plan", "attention working Plan bash echo hi"])
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

  /// With more than one place, the cycling child would push another's id out, and that
  /// child's late event would read as the parent's Done.
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

  /// A task resumed by its id reuses its session and publishes no `session.created`
  /// (opencode `tool/task.ts`), so a plugin that has lost the id must ask for it.
  @Test func aResumedChildsFirstMessageStartsNoTurnOfTheParents() throws {
    let out = try reports(
      of: [.message(session: "parent"), .message(session: "parent/a"), .idle("parent/a")],
      sessions: ["parent/a": ["id": "parent/a", "parentID": "parent"]])
    #expect(
      out.map(said) == [
        "running true", "running started", "running working", "running ended",
      ])
  }

  @Test func aLookupThatFailsLeavesTheSessionTheParents() throws {
    let out = try reports(
      of: [.message(session: "parent"), .idle("parent")],
      sessions: ["parent": ["throws": "true"]])
    #expect(out.map(said) == ["running true", "done"])
  }

  @Test(arguments: [[:], ["parent": ["hangs": "true"]]])
  func theParentIsLookedUpOnceHoweverTheLookupEnds(sessions: [String: [String: String]]) throws {
    let out = try run(
      [
        .message(session: "parent"), .tool(session: "parent"), .tool(session: "parent"),
        .idle("parent"),
      ],
      sessions: sessions)
    #expect(out.reports.map(said) == ["running true", "running", "running", "done"])
    #expect(out.waits == 1)
  }

  @Test func aChildWhoseLookupAnswersAfterTheBoundIsPutBackWhenItLands() throws {
    let out = try reports(
      of: [.message(session: "parent/a"), .pause, .idle("parent/a")],
      sessions: ["parent/a": ["id": "parent/a", "parentID": "parent", "late": "true"]])
    #expect(out.map(said) == ["running true", "running started", "running ended"])
  }

  @Test func aChildPutBackByALookupIsNotStartedAgainByALateCreation() throws {
    let out = try reports(
      of: [
        .message(session: "parent/a"), .created(child: "a", of: "parent", agent: "Explore"),
        .idle("parent/a"),
      ],
      sessions: ["parent/a": ["id": "parent/a", "parentID": "parent"]])
    #expect(out.map(said) == ["running started", "running working", "running ended"])
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

    // The plugin's one-second bound fires at once and holds node open, a hung
    // lookup leaving nothing else pending; each one begun is counted.
    let waits = 0
    const timeout = globalThis.setTimeout
    globalThis.setTimeout = (callback, delay) => {
      if (delay !== 1000) return timeout(callback, delay)
      waits += 1
      const timer = timeout(callback, 0)
      timer.unref = () => timer
      return timer
    }
    const sessions = JSON.parse(process.argv[3])
    const get = async ({ path }) => {
      if (sessions[path.id] && sessions[path.id].throws) throw new Error("unreachable")
      if (sessions[path.id] && sessions[path.id].hangs) return new Promise(() => {})
      if (sessions[path.id] && sessions[path.id].late) {
        return new Promise((resolve) => timeout(() => resolve({ data: sessions[path.id] }), 20))
      }
      return { data: sessions[path.id] }
    }
    const client = { session: { get } }
    const plugin = await MultishellPlugin({ directory: "/w", worktree: "/w", client })
    for (const step of JSON.parse(process.argv[2])) {
      if (step.hook === "pause") await new Promise((resolve) => timeout(resolve, 100))
      else if (step.hook === "event") await plugin.event({ event: step.event })
      else await plugin[step.hook](step.input, step.output)
    }
    process.stdout.write(JSON.stringify({ waits }) + "\\n")

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
