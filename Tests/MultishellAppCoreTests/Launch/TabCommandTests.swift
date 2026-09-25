import Foundation
import TestScratch
import Testing

@testable import MultishellAppCore
@testable import MultishellCore
@testable import MultishellProcess

@Suite
struct TabCommandTests {
  private let zsh = ShellInvocation(
    executable: URL(fileURLWithPath: "/bin/zsh"), arguments: ["-l", "-i", "-c"])

  @Test func theAgentRunsInTheLoginShellAndAShellTakesOverAfterIt() {
    let command = TabCommand.running(
      ["claude", "--continue"], shell: zsh, exec: "exec /bin/zsh -l")
    #expect(command == ["/bin/zsh", "-l", "-i", "-c", "claude --continue; exec /bin/zsh -l"])
  }

  @Test func argumentsWithSpacesAreQuotedAndTheUsersShellIsExecd() {
    let command = TabCommand.running(
      ["my agent", "--name", "it's"], shell: zsh, exec: "exec /opt/homebrew/bin/nu -l")
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
        executable: URL(fileURLWithPath: tcsh), arguments: ["-f", "-i", "-c"]), exec: "exit")
    let text = try await Detached.output(
      of: command[0], Array(command.dropFirst()),
      environment: ["PATH": "/usr/bin:/bin", "HISTFILE": "", "HOME": home.path])

    #expect(text == words.map { "[\($0)]\n" }.joined())
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
      let values = AgentPlaceholder.values(project: project, worktree: worktree, name: hostile)
      let command = TabCommand.running(
        ["/usr/bin/printf", "[%s]\\n"] + AgentFlags.arguments("--name={{branch}}", values: values),
        shell: ShellInvocation(executable: URL(fileURLWithPath: shell), arguments: flags),
        exec: "exit")
      let text = try await Detached.output(
        of: command[0], Array(command.dropFirst()),
        environment: ["PATH": "/usr/bin:/bin", "HISTFILE": "", "HOME": home.path],
        standardError: .discarded)

      #expect(text == "[--name=\(hostile)]\n", "\(shell)")
      #expect(!FileManager.default.fileExists(atPath: ran), "\(shell) ran \(hostile)")
    }
  }

  @Test func aCustomLineIsUsedAsTypedAndBlankMeansNothing() {
    #expect(
      TabCommand.running(customLine: ShellLine(text: "  "), shell: zsh, exec: "exec /bin/zsh -l")
        == nil)
    #expect(
      TabCommand.running(
        customLine: ShellLine(text: " my-agent --model x \n"), shell: zsh,
        exec: "exec /bin/zsh -l")
        == ["/bin/zsh", "-l", "-i", "-c", "my-agent --model x; exec /bin/zsh -l"])
  }

  @Test func theValuesACustomLineReadsAreSetAroundTheShellByEnv() {
    let line = ShellLine(
      text: #"my-agent --name "$MULTISHELL_BRANCH""#,
      environment: ["MULTISHELL_BRANCH": "feat$(x)", "MULTISHELL_PROJECT_NAME": "demo"])
    #expect(
      TabCommand.running(customLine: line, shell: zsh, exec: "exec /bin/zsh -l") == [
        "/usr/bin/env", "MULTISHELL_BRANCH=feat$(x)", "MULTISHELL_PROJECT_NAME=demo",
        "/bin/zsh", "-l", "-i", "-c", #"my-agent --name "$MULTISHELL_BRANCH"; exec /bin/zsh -l"#,
      ])
  }
}
