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
      ["claude", "--continue"], shell: .loginZsh, handOver: "exec /bin/zsh -l")
    #expect(command == ["/bin/zsh", "-l", "-i", "-c", "claude --continue; exec /bin/zsh -l"])
  }

  @Test func argumentsWithSpacesAreQuotedAndTheUsersShellIsExecd() {
    let command = TabCommand.running(
      ["my agent", "--name", "it's"], shell: .loginZsh, handOver: "exec /opt/homebrew/bin/nu -l")
    #expect(command.last == "'my agent' --name 'it'\\''s'; exec /opt/homebrew/bin/nu -l")
  }

  @Test func anArgumentWithABangOrBackslashReachesTheAgentUnderInteractiveTcsh() async throws {
    let tcsh = "/bin/tcsh"
    guard FileManager.default.isExecutableFile(atPath: tcsh) else { return }
    let home = try Scratch.directory("tab-command")
    defer { Scratch.remove(home) }
    let words = ["/code/a!b", #"back\\slash"#]
    let command = TabCommand.running(
      ["/usr/bin/printf", "[%s]\\n"] + words,
      shell: ShellInvocation(
        executable: URL(fileURLWithPath: tcsh), arguments: ["-f", "-i", "-c"]), handOver: "exit")
    let text = try await Detached.output(
      of: command[0], Array(command.dropFirst()),
      environment: Scratch.bareShellEnvironment(home: home))

    #expect(text == words.map { "[\($0)]\n" }.joined())
  }

  @Test func theHandOverReachesZshWithItsDirectoryIntactUnderInteractiveTcsh() async throws {
    let tcsh = "/bin/tcsh"
    guard FileManager.default.isExecutableFile(atPath: tcsh) else { return }
    let home = try Scratch.directory("hand-over")
    defer { Scratch.remove(home) }
    let zshDirectory = home.appendingPathComponent("a!b")
    try FileManager.default.createDirectory(at: zshDirectory, withIntermediateDirectories: true)
    let zsh = home.appendingPathComponent("zsh")
    try "#!/bin/sh\nprintf '[%s]\\n' \"$ZDOTDIR\"\n".write(
      to: zsh, atomically: true, encoding: .utf8)
    try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: zsh.path)
    let missing = URL(fileURLWithPath: "/no/such")
    let command = TabCommand.running(
      ["true"],
      shell: ShellInvocation(
        executable: URL(fileURLWithPath: tcsh), arguments: ["-f", "-i", "-c"]),
      handOver: TabCommand.commandLine(
        ShellLaunch.execArguments(forShell: zsh.path, zshDirectory: zshDirectory, bashInit: missing)
      ))
    let text = try await Detached.output(
      of: command[0], Array(command.dropFirst()),
      environment: Scratch.bareShellEnvironment(home: home), standardError: .discarded)

    #expect(text.contains("[\(zshDirectory.path)]"), "\(text)")
  }

  @Test(arguments: [
    ("/bin/zsh", ["-f", "-i", "-c"]), ("/bin/bash", ["--norc", "-i", "-c"]),
    ("/bin/sh", ["-c"]), ("/bin/tcsh", ["-f", "-i", "-c"]),
  ])
  func aBranchNameInAFlagReachesTheAgentAsTextAndRunsNothing(
    shell: String, flags: [String]
  ) async throws {
    guard FileManager.default.isExecutableFile(atPath: shell) else { return }
    let home = try Scratch.directory("tab-command")
    defer { Scratch.remove(home) }
    let ran = home.appendingPathComponent("ran").path
    let project = Project(path: URL(fileURLWithPath: "/repos/demo"))
    for hostile in ["$(touch \(ran))", "`touch \(ran)`", "a;touch \(ran)"] {
      let worktree = Worktree(
        path: URL(fileURLWithPath: "/repos/demo-worktrees/w"), projectID: project.id, head: "a",
        branch: hostile)
      let values = WorktreePlaceholder.values(
        project: project, worktree: worktree, worktreeName: hostile)
      let command = TabCommand.running(
        ["/usr/bin/printf", "[%s]\\n"] + AgentFlags.arguments("--name={{branch}}", values: values),
        shell: ShellInvocation(executable: URL(fileURLWithPath: shell), arguments: flags),
        handOver: "exit")
      let text = try await Detached.output(
        of: command[0], Array(command.dropFirst()),
        environment: Scratch.bareShellEnvironment(home: home),
        standardError: .discarded)

      #expect(text == "[--name=\(hostile)]\n", "\(shell)")
      #expect(!FileManager.default.fileExists(atPath: ran), "\(shell) ran \(hostile)")
    }
  }

  @Test func aCustomLineIsUsedAsTypedAndBlankMeansNothing() {
    #expect(
      TabCommand.running(
        customLine: ShellLine(text: "  "), shell: .loginZsh, handOver: "exec /bin/zsh -l")
        == nil)
    #expect(
      TabCommand.running(
        customLine: ShellLine(text: " my-agent --model x \n"), shell: .loginZsh,
        handOver: "exec /bin/zsh -l")
        == ["/bin/zsh", "-l", "-i", "-c", "my-agent --model x; exec /bin/zsh -l"])
  }

  @Test func theValuesACustomLineReadsAreSetAroundTheShellByEnv() {
    let line = ShellLine(
      text: #"my-agent --name "$MULTISHELL_BRANCH""#,
      environment: ["MULTISHELL_BRANCH": "feat$(x)", "MULTISHELL_PROJECT_NAME": "demo"])
    #expect(
      TabCommand.running(customLine: line, shell: .loginZsh, handOver: "exec /bin/zsh -l") == [
        "/usr/bin/env", "MULTISHELL_BRANCH=feat$(x)", "MULTISHELL_PROJECT_NAME=demo",
        "/bin/zsh", "-l", "-i", "-c", #"my-agent --name "$MULTISHELL_BRANCH"; exec /bin/zsh -l"#,
      ])
  }
}
