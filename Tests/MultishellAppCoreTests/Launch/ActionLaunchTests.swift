import Foundation
import TestScratch
import Testing

@testable import MultishellAppCore
@testable import MultishellCore

@Suite
struct ActionLaunchTests {
  private struct Run {
    let output: String
    let reports: [String]
  }

  private static let handOverMark = "--handed-over--"

  private func run(
    _ command: String,
    values: [WorktreePlaceholder: String] = [:],
    hasPort: Bool = true,
    directory: URL? = nil,
    environment extra: [String: String] = [:],
    zshenv: String? = nil,
  ) async throws -> Run {
    let home = try Scratch.directory("action-launch")
    defer { Scratch.remove(home) }
    if let zshenv {
      try zshenv.write(
        to: home.appendingPathComponent(".zshenv"),
        atomically: true,
        encoding: .utf8,
      )
    }
    let log = home.appendingPathComponent("reports.log")
    let helper = try Scratch.script(
      #"printf '%s\n' "$*" >> "\#(log.path)""#,
      at: home.appendingPathComponent("helper"),
    )
    let tabShell = try Scratch.script(
      #"""
      printf '%s HISTFILE=%s SCRIPT=%s PORT=%s BRANCH=%s\n' '\#(Self.handOverMark)' \
        "${HISTFILE-unset}" "${MULTISHELL_ACTION_SCRIPT-unset}" "${MULTISHELL_PORT-unset}" \
        "${MULTISHELL_BRANCH-unset}"
      """#,
      at: home.appendingPathComponent("tab-shell"),
    )
    let line = ActionLaunch.command(
      for: ProjectAction(name: "Start Server", command: command),
      values: values,
      in: directory ?? home,
      hasPort: hasPort,
      tabShell: tabShell.path,
      loginShell: "/bin/zsh",
      helper: helper,
    )
    let output = try await Detached.output(
      of: line[0],
      Array(line.dropFirst()),
      environment: Scratch.bareShellEnvironment(home: home).merging(extra) { $1 },
      standardError: .discarded,
    )
    let reports = (try? String(contentsOf: log, encoding: .utf8))?.split(separator: "\n")
    return Run(output: output, reports: reports?.map(String.init) ?? [])
  }

  @Test func theScriptRunsInTheWorktreeAndItsEndIsToldBeforeTheTabsShellTakesOver() async throws {
    let directory = try Scratch.directory("action-worktree")
    defer { Scratch.remove(directory) }

    let run = try await run(#"printf 'in %s\n' "$(pwd -P)""#, directory: directory)

    let physical = try #require(Scratch.physicalPath(of: directory))
    #expect(run.output.contains("in \(physical)\n"))
    #expect(run.output.contains("\u{1B}]133;C\u{07}"))
    #expect(run.output.contains("\u{1B}]133;D;0\u{07}"))
    #expect(run.output.contains(Self.handOverMark))
    #expect(run.reports.first?.hasPrefix("command-started --pid ") == true)
    #expect(run.reports.last?.hasPrefix("command-finished --exit 0 --duration ") == true)
  }

  @Test func theEndIsToldWithHowManyWholeSecondsTheScriptRan() async throws {
    let run = try await run("sleep 1")

    let finished = try #require(run.reports.last)
    let duration = finished.split(separator: " ").last.flatMap { Int($0) }
    #expect(finished.hasPrefix("command-finished --exit 0 --duration "))
    #expect(duration.map { (1...2).contains($0) } == true)
  }

  @Test func theFirstFailingLineEndsTheScriptAndTheTabStillGetsItsShell() async throws {
    let run = try await run("echo first\nfalse\necho never")

    #expect(run.output.contains("first\n"))
    #expect(!run.output.contains("never"))
    #expect(run.output.contains("\u{1B}]133;D;1\u{07}"))
    #expect(run.reports.last?.hasPrefix("command-finished --exit 1 --duration ") == true)
    #expect(run.output.contains(Self.handOverMark))
  }

  @Test func theWorktreesValuesArriveInTheirVariablesAndAreNeverScriptText() async throws {
    let home = try Scratch.directory("action-values")
    defer { Scratch.remove(home) }
    let planted = home.appendingPathComponent("planted")
    let branch = "x$(touch \(planted.path))"

    let run = try await run(
      #"printf '[%s] [%s]\n' "$MULTISHELL_BRANCH" "$MULTISHELL_PORT""#,
      values: [.branch: branch, .port: "3010"],
    )

    #expect(run.output.contains("[\(branch)] [3010]\n"))
    #expect(!FileManager.default.fileExists(atPath: planted.path))
  }

  @Test func neitherTheHistoryFileTheScriptNorItsValuesReachTheShellThatTakesOver() async throws {
    let run = try await run(
      #"echo "$MULTISHELL_BRANCH""#,
      values: [.branch: "feature-x"],
      environment: ["MULTISHELL_PORT": "3010"],
    )

    #expect(run.output.contains("feature-x\n"))
    #expect(run.output.contains("HISTFILE=unset SCRIPT=unset PORT=3010 BRANCH=unset"))
  }

  @Test func aWorktreeWithNoPortBlockLeavesThePortUnsetWhateverTheRcFilesSaid() async throws {
    let run = try await run(
      #"printf 'port=%s\n' "${MULTISHELL_PORT-unset}""#,
      hasPort: false,
      zshenv: "export MULTISHELL_PORT=3010\n",
    )

    #expect(run.output.contains("port=unset\n"))
  }

  @Test func anInterruptEndsTheScriptButNotTheWrapperSoItsEndIsStillTold() async throws {
    let run = try await run("kill -INT 0\nsleep 30\necho never")

    #expect(!run.output.contains("never"))
    #expect(run.reports.last?.hasPrefix("command-finished --exit 130 --duration ") == true)
    #expect(run.output.contains(Self.handOverMark))
  }

  @Test func aWorktreeFolderThatHasGoneIsAFailureAndTheTabStillGetsItsShell() async throws {
    let run = try await run(
      "echo never",
      directory: URL(fileURLWithPath: "/no/such/worktree"),
    )

    #expect(!run.output.contains("never"))
    #expect(run.reports.last?.hasPrefix("command-finished --exit 1 --duration ") == true)
    #expect(run.output.contains(Self.handOverMark))
  }
}
