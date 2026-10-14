import Foundation
import TestScratch
import Testing

@testable import MultishellCLI
@testable import MultishellCore
@testable import MultishellProcess

@Suite(.serialized)
struct HelperControlTests {
  @Test func aControlCommandGoesToItsOwnBuildsSocketNotThePanes() {
    let pane = ["MULTISHELL_SOCKET": "/tmp/another-copy.sock"]

    #expect(Helper.controlSocket(in: pane) == Paths.socketFile)
  }

  @Test func aTabCommandSendsItsWorktreeAndCommandAndPrintsTheAnswer() async throws {
    let app = try ControlListener(reply: .output(#"{"tab":"T"}"#))
    defer { app.stop() }

    let output = try await HelperBinary.run(
      ["tabs", "open", "w-0123abcd", "--", "npm", "run", "--watch"],
      environment: app.environment,
    )

    #expect(output.succeeded, "\(output.standardError)")
    #expect(output.standardOutput == #"{"tab":"T"}"# + "\n")
    let request = try #require(app.requests.received.first)
    guard case .newTab(let order) = request else {
      Issue.record("asked \(request)")
      return
    }
    #expect(order.worktreeID == "w-0123abcd")
    #expect(order.command == ["npm", "run", "--watch"])
    #expect(order.agentID == nil)
  }

  @Test func eachCommandAsksForWhatItsWordsSay() async throws {
    let app = try ControlListener(reply: .done)
    defer { app.stop() }
    let id = UUID()
    let other = UUID()
    let lines: [([String], ControlRequest)] = [
      (["info"], .info),
      (["config", "global", "list"], .readGlobalSettings(key: nil)),
      (["config", "global", "get", "themeID"], .readGlobalSettings(key: "themeID")),
      (
        ["config", "global", "set", "autoStartAgent", "true"],
        .writeGlobalSetting(key: "autoStartAgent", value: "true"),
      ),
      (
        ["config", "project", "p-0123abcd", "get", "branchPrefix"],
        .readProjectSettings(project: "p-0123abcd", key: "branchPrefix"),
      ),
      (
        ["config", "project", "p-0123abcd", "set", "iconTint", "3"],
        .writeProjectSetting(project: "p-0123abcd", key: "iconTint", value: "3"),
      ),
      (["projects", "list"], .listProjects),
      (["projects", "add", "/repo"], .addProject(path: "/repo")),
      (
        ["projects", "remove", "p-0123abcd", "--force"],
        .removeProject(id: "p-0123abcd", force: true),
      ),
      (["worktrees", "list"], .listWorktrees(project: nil)),
      (["worktrees", "list", "p-0123abcd"], .listWorktrees(project: "p-0123abcd")),
      (
        ["worktrees", "remove", "w-89abcdef", "--delete-branch"],
        .removeWorktree(
          WorktreeRemovalOrder(
            worktreeID: "w-89abcdef",
            deletesBranch: true,
            forcesBranchDeletion: false,
            force: false,
          )
        ),
      ),
      (
        ["worktrees", "remove", "w-89abcdef", "--force-delete-branch", "--force"],
        .removeWorktree(
          WorktreeRemovalOrder(
            worktreeID: "w-89abcdef",
            deletesBranch: true,
            forcesBranchDeletion: true,
            force: true,
          )
        ),
      ),
      (["worktrees", "select", "w-89abcdef"], .selectWorktree(id: "w-89abcdef")),
      (["tabs", "list"], .listTabs(worktree: nil)),
      (["tabs", "list", "w-89abcdef"], .listTabs(worktree: "w-89abcdef")),
      (["tabs", "select", id.uuidString], .selectTab(id: id)),
      (["tabs", "close", id.uuidString, "--force"], .closeTab(id: id, force: true)),
      (
        ["tabs", "move", id.uuidString, "--after", other.uuidString],
        .moveTab(id: id, placement: .after, anchor: other),
      ),
      (["tabs", "rename", id.uuidString, "Server"], .renameTab(id: id, title: "Server")),
      (["tabs", "rename", id.uuidString], .renameTab(id: id, title: nil)),
      (
        ["panes", "split", "--down", "--tab", id.uuidString], .splitPane(axis: .vertical, tab: id),
      ),
      (["panes", "split"], .splitPane(axis: .horizontal, tab: nil)),
      (["panes", "select", id.uuidString], .selectPane(id: id)),
      (["panes", "close", id.uuidString], .closePane(id: id, force: false)),
      (
        ["panes", "type", id.uuidString, "make test", "--enter"],
        .typeIntoPane(id: id, text: "make test", pressingReturn: true),
      ),
      (
        ["panes", "type", id.uuidString, "--enter", "--", "-y"],
        .typeIntoPane(id: id, text: "-y", pressingReturn: true),
      ),
      (
        ["panes", "type", id.uuidString, "--", "--continue"],
        .typeIntoPane(id: id, text: "--continue", pressingReturn: false),
      ),
      (["tabs", "rename", id.uuidString, "--", "- wip"], .renameTab(id: id, title: "- wip")),
      (["panes", "show", id.uuidString], .describePane(id: id)),
      (["ui", "show", "board"], .showView(.agentBoard, project: nil)),
      (
        ["ui", "show", "project-settings", "p-0123abcd"],
        .showView(.projectSettings, project: "p-0123abcd"),
      ),
      (["ui", "hide", "settings"], .hideView(.settings)),
      (["ui", "filter", "feat"], .filterSidebar(text: "feat")),
      (["ui", "filter"], .filterSidebar(text: "")),
      (["ui", "dismiss"], .dismissPresentation),
      (["window", "size", "900", "600"], .resizeWindow(width: 900, height: 600)),
      (["window", "full-screen", "on"], .setFullScreen(on: true)),
      (
        ["panes", "key", id.uuidString, "ctrl-c", "escape"],
        .pressKeys(
          id: id,
          keys: [ControlKey(parsing: "ctrl-c")!, ControlKey(parsing: "escape")!],
        ),
      ),
      (["board", "list"], .listBoard),
      (["sidebar", "list"], .listSidebar),
      (["tabs", "show", id.uuidString], .describeTab(id: id)),
      (["worktrees", "show", "w-89abcdef"], .describeWorktree(id: "w-89abcdef")),
      (
        ["worktrees", "rename", "w-89abcdef", "Trunk"],
        .renameWorktree(id: "w-89abcdef", name: "Trunk"),
      ),
      (["worktrees", "rename", "w-89abcdef"], .renameWorktree(id: "w-89abcdef", name: nil)),
      (["panes", "paste", id.uuidString, "--", "-a\nb"], .pasteIntoPane(id: id, text: "-a\nb")),
      (
        ["panes", "key", id.uuidString, "-", "escape"],
        .pressKeys(id: id, keys: [ControlKey(parsing: "-")!, ControlKey(parsing: "escape")!]),
      ),
      (["ui", "menu"], .listMenuItems),
      (
        ["ui", "menu", "View > Enable Debug Tools"],
        .performMenuItem(path: ["View", "Enable Debug Tools"]),
      ),
      (["ui", "menu", "Edit", "Find…"], .performMenuItem(path: ["Edit", "Find…"])),
      (["debug", "notifications"], .debugNotifications),
      (["debug", "samples", "--summary"], .debugSummary(last: 60)),
      (["debug", "samples", "--summary", "--last", "5"], .debugSummary(last: 5)),
      (["debug", "git"], .debugGitRuns(last: 20)),
      (["debug", "git", "--last", "3"], .debugGitRuns(last: 3)),
      (["debug", "mark", "open tabs"], .markDebugSample(name: "open tabs")),
      (
        ["debug", "report", id.uuidString, "attention", "--agent", "claude", "--message", "Hi"],
        .reportPaneState(
          SessionStateReport(state: .attention, sessionID: id, message: "Hi", agentID: "claude")
        ),
      ),
      (["debug", "tools", "on"], .setDebugTools(enabled: true)),
      (["debug", "info", "hide"], .setDebugInfo(shown: false)),
      (["debug", "samples", "--last", "5"], .debugSamples(last: 5)),
      (["debug", "samples"], .debugSamples(last: 1)),
      (["debug", "memory"], .debugMemory),
    ]
    for (line, _) in lines {
      let output = try await HelperBinary.run(line, environment: app.environment)
      #expect(
        output.succeeded && output.standardOutput.isEmpty,
        "\(line): \(output.standardError)",
      )
    }

    #expect(app.requests.received == lines.map(\.1))
  }

  @Test func aWorktreeCommandNamesItsBranchProjectAndFirstTab() async throws {
    let app = try ControlListener(reply: .done)
    defer { app.stop() }

    let output = try await HelperBinary.run(
      [
        "worktrees", "add", "p-0123abcd", "feat/x", "--from", "main", "--agent", "codex",
        "--prompt", "fix the build",
      ],
      environment: app.environment,
    )

    #expect(output.succeeded, "\(output.standardError)")
    let expected = NewWorktreeOrder(
      branch: "feat/x",
      projectID: "p-0123abcd",
      createsBranch: true,
      startPoint: "main",
      agentID: "codex",
      task: "fix the build",
    )
    #expect(app.requests.received == [.newWorktree(expected)])
  }

  @Test func aRefusalIsSaidInWordsAndExitsOne() async throws {
    let app = try ControlListener(reply: .refused(.agentWorking))
    defer { app.stop() }

    let output = try await HelperBinary.run(
      ["tabs", "close", UUID().uuidString],
      environment: app.environment,
    )

    #expect(output.status == 1)
    #expect(output.standardError.contains("--force goes ahead anyway"), "\(output.standardError)")
  }

  @Test func aRequestTooLongForTheAppIsSaidSoAndNotSent() async throws {
    let app = try ControlListener(reply: .done)
    defer { app.stop() }
    let text = String(repeating: "a", count: UnixSocketServer.maximumLineLength + 1)

    let output = try await HelperBinary.run(
      ["panes", "type", UUID().uuidString, text],
      environment: app.environment,
    )

    #expect(output.status == 1)
    #expect(output.standardError.contains("too long"), "\(output.standardError)")
    #expect(app.requests.received.isEmpty)
  }

  @Test func anAppThatAnswersNothingIsTakenForAnOlderOne() async throws {
    let app = try ControlListener(reply: nil)
    defer { app.stop() }

    let output = try await HelperBinary.run(["tabs", "list"], environment: app.environment)

    #expect(output.status == 1)
    #expect(output.standardError.contains("older than this helper"), "\(output.standardError)")
  }

  @Test func aPathOrANameWhereAnIDGoesIsAUsageError() async throws {
    for line in [
      ["worktrees", "list", "/repo"], ["tabs", "open", "main"],
      ["config", "project", ".", "list"], ["projects", "remove", "p-NOTHEX!!"],
    ] {
      let output = try await HelperBinary.run(line)
      #expect(output.status == 2, "\(line)")
      #expect(output.standardError.contains("not a "), "\(line): \(output.standardError)")
    }
  }

  @Test func noAppListeningExitsOneSayingSo() async throws {
    let output = try await HelperBinary.run(
      ["debug", "memory"],
      environment: [Helper.controlSocketVariable: HelperBinary.nobodyListening],
    )

    #expect(output.status == 1)
    #expect(output.standardError.contains("could not reach Multishell"), "\(output.standardError)")
  }

  @Test func malformedControlLinesAreUsageErrorsThatAskNothing() async throws {
    let app = try ControlListener(reply: .done)
    defer { app.stop() }
    let lines = [
      ["tabs", "close", "not-an-id"],
      ["tabs", "open", "--"],
      ["tabs", "open", "--agent", "claude", "--", "make"],
      ["tabs", "move", UUID().uuidString],
      [
        "tabs", "move", UUID().uuidString, "--before", UUID().uuidString, "--after",
        UUID().uuidString,
      ],
      ["tabs", "frobnicate"],
      ["panes", "select"],
      ["debug", "samples", "--last", "0"],
      ["debug", "tools", "maybe"],
      ["worktrees", "add"],
      ["worktrees", "add", "x", "--existing", "--from", "main"],
      ["worktrees", "remove"],
      ["projects", "remove"],
      ["config", "global", "set", "autoStartAgent"],
      ["config", "elsewhere", "list"],
      ["window", "full-screen", "maybe"],
      ["open", "a"],
      ["info", "extra"],
    ]
    for line in lines {
      let output = try await HelperBinary.run(line, environment: app.environment)
      #expect(output.status == 2, "\(line)")
    }

    #expect(app.requests.received.isEmpty)
  }
}
