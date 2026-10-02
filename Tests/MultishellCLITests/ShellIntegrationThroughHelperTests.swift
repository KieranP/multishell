import Foundation
import TestScratch
import Testing

@testable import MultishellCore
@testable import MultishellProcess

/// The generated zsh and bash files driven by real shells, reporting
/// through the built helper to a socket standing in for the app.
@Suite(.serialized)
struct ShellIntegrationThroughHelperTests {
  @Test func zshIntegrationLoadsUserConfigAndReportsThroughInjectedHooks() async throws {
    guard FileManager.default.isExecutableFile(atPath: "/bin/zsh") else { return }
    let listener = try ReportListener()
    defer { listener.stop() }
    let recorder = listener.recorder

    let root = try Scratch.directory("inject")
    defer { Scratch.remove(root) }
    let integration = try ShellTab.zshIntegrationDirectory(in: root)
    let userZdotdir = try ShellTab.userZdotdir(in: root)
    try "export MULTISHELL_USER_RC_LOADED=yes\n".write(
      to: userZdotdir.appendingPathComponent(".zshrc"), atomically: true, encoding: .utf8)

    let session = UUID()
    let environment = ShellTab.zshEnvironment(
      socket: listener.path, session: session, worktree: "/w/repo", integration: integration,
      userZdotdir: userZdotdir)
    let script = """
      printf 'loaded=%s zdotdir=%s\\n' "$MULTISHELL_USER_RC_LOADED" "$ZDOTDIR"
      _multishell_preexec; true; _multishell_precmd
      _multishell_preexec; false; _multishell_precmd
      wait
      """
    let output = try await ShellTab.runZsh(script, in: root, environment: environment)

    #expect(
      output.standardOutput.contains("loaded=yes"),
      "the user's .zshrc did not run: \(output.standardOutput)")
    #expect(
      output.standardOutput.contains("zdotdir=\(userZdotdir.path)"),
      "ZDOTDIR was not handed back to the user for nested shells: \(output.standardOutput)")

    try await waitUntil { recorder.received.count >= 4 }
    let states = recorder.received.compactMap { SessionStateReport.parse($0)?.state }
    #expect(states.filter { $0 == .running }.count == 2, "\(states)")
    #expect(states.contains(.done) && states.contains(.failed), "\(states)")
    #expect(SessionStateReport.parse(recorder.received.first ?? "")?.sessionID == session)
  }

  @Test func zshBuildsTheLineItSendsInAVariableRatherThanASubshell() async throws {
    guard FileManager.default.isExecutableFile(atPath: "/bin/zsh") else { return }
    let root = try Scratch.directory("zsh-json")
    defer { Scratch.remove(root) }
    let integration = try ShellTab.zshIntegrationDirectory(
      in: root, helper: URL(filePath: "/bin/echo"))
    var environment = ShellTab.zshEnvironment(
      socket: URL(fileURLWithPath: "/nonexistent.sock"), home: root, integration: integration,
      userZdotdir: root)
    environment["MULTISHELL_SESSION"] = "s"

    let output = try await ShellTab.runZsh(
      #"_multishell_json idle ""; print -r -- "line=$_multishell_line""#, in: root,
      environment: environment)

    #expect(output.standardOutput.contains(#"line={"v":1,"state":"idle","session":"s""#))
  }

  /// `%f` writes the locale's decimal separator, so a comma region sent
  /// `"duration":1,234` and the reader dropped the whole report.
  @Test func aCommaDecimalLocaleStillSendsAReportThatParses() async throws {
    guard FileManager.default.isExecutableFile(atPath: "/bin/zsh") else { return }
    let comma = try await ProcessRunner().capture(
      URL(fileURLWithPath: "/bin/zsh"), ["-c", "printf '%.3f' 1.5"],
      in: URL(fileURLWithPath: "/tmp"), environment: ["LC_ALL": "de_DE.UTF-8"])
    guard comma.standardOutput.contains(",") else { return }

    let listener = try ReportListener()
    defer { listener.stop() }
    let recorder = listener.recorder

    let root = try Scratch.directory("locale")
    defer { Scratch.remove(root) }
    let integration = try ShellTab.zshIntegrationDirectory(in: root)
    // The developer's own .zshrc sets a locale of its own and would decide this test.
    var environment = ShellTab.zshEnvironment(
      socket: listener.path, worktree: "/w/repo", integration: integration,
      userZdotdir: try ShellTab.userZdotdir(in: root))
    environment["LC_ALL"] = "de_DE.UTF-8"
    _ = try await ShellTab.runZsh(
      "_multishell_preexec; true; _multishell_precmd; wait", in: root, environment: environment)

    try await waitUntil { recorder.received.count >= 2 }
    let finished = recorder.received.compactMap(SessionStateReport.parse).filter {
      $0.state == .done
    }
    #expect(finished.count == 1, "unparsed: \(recorder.received)")
    #expect(finished.first?.duration != nil, "the duration is what the separator broke")
  }

  @Test func zshIntegrationFollowsAZdotdirSetByTheUsersZshenv() async throws {
    guard FileManager.default.isExecutableFile(atPath: "/bin/zsh") else { return }
    let listener = try ReportListener()
    defer { listener.stop() }
    let recorder = listener.recorder

    let root = try Scratch.directory("relocate")
    defer { Scratch.remove(root) }
    let integration = try ShellTab.zshIntegrationDirectory(in: root)
    let home = root.appendingPathComponent("home", isDirectory: true)
    let relocated = home.appendingPathComponent(".config/zsh", isDirectory: true)
    try FileManager.default.createDirectory(at: relocated, withIntermediateDirectories: true)
    try "export ZDOTDIR=\"$HOME/.config/zsh\"\n".write(
      to: home.appendingPathComponent(".zshenv"), atomically: true, encoding: .utf8)
    try "export MULTISHELL_USER_RC_LOADED=relocated\n".write(
      to: relocated.appendingPathComponent(".zshrc"), atomically: true, encoding: .utf8)

    var environment = ShellTab.environment(socket: listener.path, home: home)
    environment["ZDOTDIR"] = integration.path
    environment.removeValue(forKey: "MULTISHELL_USER_ZDOTDIR")
    let output = try await ShellTab.runZsh(
      "printf '%s|%s' \"$MULTISHELL_USER_RC_LOADED\" \"$ZDOTDIR\"; _multishell_preexec",
      in: root, environment: environment)

    let fields = output.standardOutput.split(separator: "|", omittingEmptySubsequences: false)
    #expect(
      fields.first == "relocated", "the relocated .zshrc did not run: \(output.standardOutput)")
    #expect(
      fields.count == 2 && fields[1] == relocated.path,
      "ZDOTDIR handed back to the relocated dir: \(output.standardOutput)")
    try await waitUntil { !recorder.received.isEmpty }
    #expect(SessionStateReport.parse(recorder.received.first ?? "")?.state == .running)
  }

  /// Only a login shell reads ~/.zprofile.
  @Test func zshIntegrationFollowsAZdotdirSetByTheUsersZprofile() async throws {
    guard FileManager.default.isExecutableFile(atPath: "/bin/zsh") else { return }
    let root = try Scratch.directory("profile")
    defer { Scratch.remove(root) }
    let integration = try ShellTab.zshIntegrationDirectory(in: root)
    let home = root.appendingPathComponent("home", isDirectory: true)
    let relocated = home.appendingPathComponent(".config/zsh", isDirectory: true)
    try FileManager.default.createDirectory(at: relocated, withIntermediateDirectories: true)
    try "export ZDOTDIR=\"$HOME/.config/zsh\"\n".write(
      to: home.appendingPathComponent(".zprofile"), atomically: true, encoding: .utf8)
    try "export MULTISHELL_USER_RC_LOADED=relocated\n".write(
      to: relocated.appendingPathComponent(".zshrc"), atomically: true, encoding: .utf8)

    // The runner merges this over the process's own, which from a Multishell
    // tab names a session and a socket; blank, the hooks do nothing.
    let environment = [
      "HOME": home.path, "ZDOTDIR": integration.path, "MULTISHELL_SESSION": "",
      "MULTISHELL_SOCKET": "", "MULTISHELL_USER_ZDOTDIR": "",
    ]
    let output = try await ShellTab.runZsh(
      "printf '%s|%s' \"$MULTISHELL_USER_RC_LOADED\" \"$ZDOTDIR\"", isLogin: true, in: root,
      environment: environment)

    let fields = output.standardOutput.split(separator: "|", omittingEmptySubsequences: false)
    #expect(
      fields.first == "relocated", "the relocated .zshrc did not run: \(output.standardOutput)")
    #expect(
      fields.count == 2 && fields[1] == relocated.path,
      "ZDOTDIR handed back to the relocated dir: \(output.standardOutput)")
  }

  /// git refuses a control character in a branch name, but a parent directory
  /// may carry one, and the zsh line escaped only backslash and quote.
  @Test func aWorktreePathHoldingAControlCharacterStillReportsFromZsh() async throws {
    guard FileManager.default.isExecutableFile(atPath: "/bin/zsh") else { return }
    let listener = try ReportListener()
    defer { listener.stop() }
    let recorder = listener.recorder

    let root = try Scratch.directory("cntrl")
    defer { Scratch.remove(root) }
    let integration = try ShellTab.zshIntegrationDirectory(in: root)
    let worktree = "/w/re\tpo\nsit\"or\\y"
    let environment = ShellTab.zshEnvironment(
      socket: listener.path, worktree: worktree, integration: integration,
      userZdotdir: try ShellTab.userZdotdir(in: root))
    _ = try await ShellTab.runZsh(
      "_multishell_preexec; true; _multishell_precmd; wait", in: root, environment: environment)

    try await waitUntil { recorder.received.count >= 2 }
    let received = recorder.received
    let reports = received.compactMap(SessionStateReport.parse)
    #expect(reports.count == received.count, "unparsed: \(received)")
    #expect(Set(reports.map(\.state)).isSuperset(of: [.running, .done]), "\(reports.map(\.state))")
    #expect(
      reports.allSatisfy { $0.workingDirectory == worktree }, "\(reports.map(\.workingDirectory))")
  }
}
