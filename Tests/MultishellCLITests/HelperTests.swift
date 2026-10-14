import Foundation
import TestScratch
import Testing

@testable import MultishellCore
@testable import MultishellProcess

/// The built `multishell` binary's command line.
@Suite(.serialized)
struct HelperTests {
  @Test func usageErrorsExitTwo() async throws {
    #expect(try await HelperBinary.run([]).status == 2)
    #expect(try await HelperBinary.run(["state", "sleeping"]).status == 2)
    #expect(try await HelperBinary.run(["state", "done", "--bogus"]).status == 2)
    #expect(try await HelperBinary.run(["frobnicate"]).status == 2)
  }

  @Test func helpAndItsFlagsPrintTheOverviewToStandardOutputAndExitZero() async throws {
    for line in [["help"], ["--help"], ["-h"]] {
      let output = try await HelperBinary.run(line)
      #expect(output.succeeded, "\(line)")
      #expect(output.standardOutput.hasPrefix("usage: multishell <command>"), "\(line)")
      #expect(output.standardError.isEmpty, "\(line)")
    }
  }

  @Test func aCommandsHelpNamesItsArgumentsHoweverItIsAskedFor() async throws {
    for line in [["help", "tabs"], ["tabs", "--help"], ["tabs", "open", "-h"]] {
      let output = try await HelperBinary.run(line)
      #expect(output.succeeded, "\(line)")
      #expect(
        output.standardOutput.contains("usage: multishell tabs open WORKTREE_ID"),
        "\(line)",
      )
    }
  }

  @Test func helpOnAWordThatIsNoCommandIsAUsageError() async throws {
    #expect(try await HelperBinary.run(["help", "frobnicate"]).status == 2)
  }

  @Test func aHelpFlagLaterInALineThatFailsToParsePrintsThatCommandsHelp() async throws {
    let app = try ControlListener(reply: .done)
    defer { app.stop() }
    let id = UUID().uuidString
    for line in [
      ["tabs", "show", id, "--help"], ["config", "project", "p-0123abcd", "list", "-h"],
    ] {
      let output = try await HelperBinary.run(line, environment: app.environment)
      #expect(output.succeeded, "\(line): \(output.standardError)")
      #expect(output.standardOutput.contains("usage: multishell \(line[0])"), "\(line)")
    }
    #expect(app.requests.received.isEmpty)
  }

  @Test func aHelpFlagAfterTheTextMarkIsTypedAsText() async throws {
    let app = try ControlListener(reply: .done)
    defer { app.stop() }
    let pane = UUID()

    let output = try await HelperBinary.run(
      ["panes", "type", pane.uuidString, "--", "-h"],
      environment: app.environment,
    )

    #expect(output.succeeded, "\(output.standardError)")
    #expect(app.requests.received == [.typeIntoPane(id: pane, text: "-h", pressingReturn: false)])
  }

  @Test func anOptionsValueThatSpellsAHelpFlagIsSentNotTakenForHelp() async throws {
    let app = try ControlListener(reply: .output("{}"))
    defer { app.stop() }
    let pane = UUID()

    let output = try await HelperBinary.run(
      ["debug", "report", pane.uuidString, "done", "--message", "-h"],
      environment: app.environment,
    )

    #expect(output.succeeded, "\(output.standardError)")
    #expect(
      app.requests.received
        == [.reportPaneState(SessionStateReport(state: .done, sessionID: pane, message: "-h"))]
    )
  }

  @Test func aHookLinesValueThatSpellsAHelpFlagIsReportedNotTakenForHelp() async throws {
    let listener = try ReportListener()
    defer { listener.stop() }

    let output = try await HelperBinary.run(
      ["command-started", "--command", "-h"],
      environment: ["MULTISHELL_SOCKET": listener.path.path],
    )

    #expect(output.succeeded && output.standardOutput.isEmpty, "\(output.standardOutput)")
    let lines = try await listener.linesUpToABarrier()
    #expect(lines.count == 2)
    #expect(SessionStateReport.parse(lines.first ?? "")?.command == "-h")
  }

  @Test func theUIAndWindowCommandsHaveHelpOfTheirOwn() async throws {
    let uiHelp = try await HelperBinary.run(["help", "ui"])
    let windowHelp = try await HelperBinary.run(["window", "--help"])

    #expect(uiHelp.succeeded && uiHelp.standardOutput.contains("usage: multishell ui menu"))
    #expect(
      windowHelp.succeeded && windowHelp.standardOutput.contains("usage: multishell window size")
    )
  }

  @Test func helpOnHelpOrTheVersionIsAnsweredToo() async throws {
    for line in [["help", "--help"], ["help", "tabs", "--help"], ["version", "-h"]] {
      let output = try await HelperBinary.run(line)
      #expect(output.succeeded, "\(line): \(output.standardError)")
      #expect(output.standardOutput.hasPrefix("usage: multishell"), "\(line)")
    }
  }

  @Test func theVersionTakesNoArguments() async throws {
    #expect(try await HelperBinary.run(["--version", "extra"]).status == 2)
  }

  @Test func theVersionNamesTheReportAndControlProtocolsTheAppSpeaks() async throws {
    let version = try await HelperBinary.run(["--version"])
    let printed = try JSONSerialization.jsonObject(with: Data(version.standardOutput.utf8))
    #expect(
      (printed as? [String: Int]) == ["controlProtocolVersion": 1, "protocolVersion": 1],
      "\(version.standardOutput)",
    )
  }

  @Test func aMisspeltOptionWithAValueIsAUsageErrorForEveryReportingCommand() async throws {
    let environment = ["MULTISHELL_SOCKET": HelperBinary.nobodyListening]
    let lines = [
      ["state", "running", "--sesion", UUID().uuidString],
      ["command-started", "--pdi", "4242"],
      ["command-finished", "--exit", "0", "--duraton", "3"],
      ["relay", "--pdi", "4242"],
    ]
    for line in lines {
      let output = try await HelperBinary.run(line, environment: environment)
      #expect(output.status == 2, "\(line)")
      #expect(output.standardError.contains("unexpected argument --"), "\(line)")
    }
  }
}
