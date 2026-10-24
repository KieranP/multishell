import Foundation
import TestScratch
import Testing

@testable import MultishellAppCore
@testable import MultishellCore
@testable import MultishellProcess

@Suite
struct TabCommandTests {
  @Test func theAgentRunsInTheLoginShellAndAShellTakesOverAfterIt() {
    let command = TabCommand.running(
      ["claude", "--continue"],
      shell: .loginZsh,
      handOver: "exec /bin/zsh -l",
    )
    #expect(
      command == [
        "/bin/zsh", "-l", "-i", "-c",
        LeadingPathStatement.line(for: .loginZsh) + "claude --continue; exec /bin/zsh -l",
      ]
    )
  }

  @Test func argumentsWithSpacesAreQuotedAndTheUsersShellIsExecd() {
    let command = TabCommand.running(
      ["my agent", "--name", "it's"],
      shell: .loginZsh,
      handOver: "exec /opt/homebrew/bin/nu -l",
    )
    #expect(
      command.last?.withoutLeadingPathStatement
        == "'my agent' --name 'it'\\''s'; exec /opt/homebrew/bin/nu -l"
    )
  }

  @Test(.enabled(if: InstalledShells.isInstalled("/bin/tcsh")))
  func anArgumentWithABangOrBackslashReachesTheAgentUnderInteractiveTcsh() async throws {
    let tcsh = "/bin/tcsh"
    let home = try Scratch.directory("tab-command")
    defer { Scratch.remove(home) }
    let words = ["/code/a!b", #"back\\slash"#]
    let command = TabCommand.running(
      ["/usr/bin/printf", "[%s]\\n"] + words,
      shell: ShellInvocation(
        executable: URL(fileURLWithPath: tcsh),
        arguments: ["-f", "-i", "-c"],
      ),
      handOver: "exit",
    )
    let text = try await Detached.output(
      of: command[0],
      Array(command.dropFirst()),
      environment: Scratch.bareShellEnvironment(home: home),
    )

    #expect(text == words.map { "[\($0)]\n" }.joined())
  }

  @Test(.enabled(if: InstalledShells.isInstalled("/bin/tcsh")))
  func theHandOverReachesZshWithItsDirectoryIntactUnderInteractiveTcsh() async throws {
    let tcsh = "/bin/tcsh"
    let home = try Scratch.directory("hand-over")
    defer { Scratch.remove(home) }
    let zshDirectory = home.appendingPathComponent("a!b")
    try FileManager.default.createDirectory(at: zshDirectory, withIntermediateDirectories: true)
    let zsh = try Scratch.script(
      #"printf '[%s]\n' "$ZDOTDIR""#,
      at: home.appendingPathComponent("zsh"),
    )
    let missing = URL(fileURLWithPath: "/no/such")
    let command = TabCommand.running(
      ["true"],
      shell: ShellInvocation(
        executable: URL(fileURLWithPath: tcsh),
        arguments: ["-f", "-i", "-c"],
      ),
      handOver: AnyShellQuoting.commandLine(
        ShellLaunch.execArguments(
          forShell: zsh.path,
          zshDirectory: zshDirectory,
          bashInit: missing,
        )
      ),
    )
    let text = try await Detached.output(
      of: command[0],
      Array(command.dropFirst()),
      environment: Scratch.bareShellEnvironment(home: home),
      standardError: .discarded,
    )

    #expect(text.contains("[\(zshDirectory.path)]"), "\(text)")
  }

  @Test(
    arguments: InstalledShells.only([
      ("/bin/zsh", ["-f", "-i", "-c"]), ("/bin/bash", ["--norc", "-i", "-c"]),
      ("/bin/sh", ["-c"]), ("/bin/tcsh", ["-f", "-i", "-c"]),
    ])
  )
  func aBranchNameInAFlagReachesTheAgentAsTextAndRunsNothing(
    shell: String,
    flags: [String],
  ) async throws {
    let home = try Scratch.directory("tab-command")
    defer { Scratch.remove(home) }
    let ran = home.appendingPathComponent("ran").path
    let project = Project(path: URL(fileURLWithPath: "/repos/demo"))
    for hostile in ["$(touch \(ran))", "`touch \(ran)`", "a;touch \(ran)"] {
      let worktree = Worktree(
        path: URL(fileURLWithPath: "/repos/demo-worktrees/w"),
        projectID: project.id,
        head: "a",
        branch: hostile,
      )
      let values = WorktreePlaceholder.values(
        project: project,
        worktree: worktree,
        worktreeName: hostile,
        port: nil,
      )
      let command = TabCommand.running(
        ["/usr/bin/printf", "[%s]\\n"] + AgentFlags.arguments("--name={{branch}}", values: values),
        shell: ShellInvocation(executable: URL(fileURLWithPath: shell), arguments: flags),
        handOver: "exit",
      )
      let text = try await Detached.output(
        of: command[0],
        Array(command.dropFirst()),
        environment: Scratch.bareShellEnvironment(home: home),
        standardError: .discarded,
      )

      #expect(text == "[--name=\(hostile)]\n", "\(shell)")
      #expect(!FileManager.default.fileExists(atPath: ran), "\(shell) ran \(hostile)")
    }
  }

  /// Each user's file stands in for the `path_helper` a login profile runs.
  @Test(
    arguments: InstalledShells.only(
      ["/bin/zsh", "/bin/sh", "/bin/ksh", "/bin/dash"] + InstalledBashes.all
        + InstalledShells.fishCandidates
    )
  )
  func theAgentFindsTheAppsEntriesAheadOfWhatTheLoginProfileAdded(shell: String) async throws {
    let home = try Scratch.directory("tab-command")
    defer { Scratch.remove(home) }
    let prepend = "export PATH=\"/opt/first:$PATH\"\n"
    try Data(prepend.utf8).write(to: home.appendingPathComponent(".zprofile"))
    try Data(prepend.utf8).write(to: home.appendingPathComponent(".bash_profile"))
    try Data(prepend.utf8).write(to: home.appendingPathComponent(".profile"))
    let fishConfig = home.appendingPathComponent(".config/fish", isDirectory: true)
    try FileManager.default.createDirectory(at: fishConfig, withIntermediateDirectories: true)
    try Data("set -gx PATH /opt/first $PATH\n".utf8)
      .write(to: fishConfig.appendingPathComponent("config.fish"))
    let lead = "/lead/helper:/lead/app"
    var environment = Scratch.bareShellEnvironment(home: home)
    environment["PATH"] = lead + ":/usr/bin:/bin"
    environment[SessionEnvironment.leadingPathVariable] = lead
    let command = TabCommand.running(
      ["/usr/bin/printenv", "PATH"],
      shell: ShellInvocation(
        executable: URL(fileURLWithPath: shell),
        arguments: ["-l", "-i", "-c"],
      ),
      handOver: "exit",
    )

    let text = try await Detached.output(
      of: command[0],
      Array(command.dropFirst()),
      environment: environment,
      in: home,
      standardError: .discarded,
    )

    let path = try #require(text.split(separator: "\n").last { $0.hasPrefix("/") }, "\(text)")
    #expect(path.hasPrefix(lead + ":"), "\(shell): \(path)")
    #expect(path.contains("/opt/first"), "\(shell) read no profile: \(path)")
    #expect(path.components(separatedBy: "/lead/helper").count == 2, "\(shell): \(path)")
  }

  @Test func aCustomLineIsUsedAsTypedAndBlankMeansNothing() {
    #expect(
      TabCommand.running(
        customLine: ShellLine(text: "  "),
        shell: .loginZsh,
        handOver: "exec /bin/zsh -l",
      )
        == nil
    )
    #expect(
      TabCommand.running(
        customLine: ShellLine(text: " my-agent --model x \n"),
        shell: .loginZsh,
        handOver: "exec /bin/zsh -l",
      )
        == [
          "/bin/zsh", "-l", "-i", "-c",
          LeadingPathStatement.line(for: .loginZsh) + "my-agent --model x; exec /bin/zsh -l",
        ]
    )
  }

  @Test func theValuesACustomLineReadsAreSetAroundTheShellByEnv() {
    let line = ShellLine(
      text: #"my-agent --name "$MULTISHELL_BRANCH""#,
      environment: ["MULTISHELL_BRANCH": "feat$(x)", "MULTISHELL_PROJECT_NAME": "demo"],
    )
    #expect(
      TabCommand.running(customLine: line, shell: .loginZsh, handOver: "exec /bin/zsh -l") == [
        "/usr/bin/env", "MULTISHELL_BRANCH=feat$(x)", "MULTISHELL_PROJECT_NAME=demo",
        "/bin/zsh", "-l", "-i", "-c",
        LeadingPathStatement.line(for: .loginZsh)
          + #"my-agent --name "$MULTISHELL_BRANCH"; exec /bin/zsh -l"#,
      ]
    )
  }
}
