import Foundation
import TestScratch
import Testing

@testable import MultishellCore

/// OSC 133 marks let a click in a prompt move the cursor. zsh adds the claim to
/// Ghostty's own marks, and bash writes all of them, since Ghostty writes none for it.
extension ShellIntegrationScriptsTests {
  @Test func theZshPromptSaysAClickInItMayMoveTheCursor() {
    let zshrc =
      ShellIntegrationScripts.forZsh(helper: "/x/multishell")[".zshrc"] ?? ""
    #expect(zshrc.contains("]133;A;cl=line"))
    #expect(
      zshrc.contains("]133;B"), "and the input mark, so the claim never stands over unmarked text")
    #expect(zshrc.contains("add-zsh-hook precmd _multishell_prompt_click"), "on every prompt")
    #expect(
      zshrc.contains("add-zsh-hook preexec _multishell_terminal_preexec"),
      "and output start, so the claim does not stand while a program runs")
    #expect(
      zshrc.contains("[ \"${TERM_PROGRAM-}\" = ghostty ]"),
      "elsewhere there are no other marks, so a lone one would open a prompt it never ends")
  }

  @Test func theBashPromptCarriesEveryMarkItself() {
    let text = ShellIntegrationScripts.forBash(helper: "/x/multishell")
    #expect(text.contains("]133;A;cl=line"), "prompt start, and the claim")
    #expect(text.contains("]133;B"), "input start, or no cell is one a click can reach")
    #expect(
      text.contains("]133;C"),
      "output start, or a click would answer with arrows while a program runs")
    #expect(text.contains("133;D") == false, "the exit code is the socket's to report, not both")
    // Separated by a newline, not `; `: a user's own PROMPT_COMMAND ending
    // in a separator composed to `;;` and bash refused the whole string.
    #expect(
      text.range(of: "_multishell_prompt_marks\n_multishell_arm") != nil,
      "put back last, after a framework has rebuilt PS1 from a PROMPT_COMMAND of its own")
    #expect(
      text.range(of: "_multishell_prompt_marks; _multishell_arm") == nil,
      "a separator of its own is what a trailing one in theirs doubles")
  }

  /// The generated files are a chain, and a hook dropped from it would leave every
  /// file valid shell, so only a real shell at a prompt shows the claim.
  @Test(.enabled(if: InstalledShells.isInstalled("/bin/zsh")))
  func aRealZshWritesTheClaimAtItsPromptUnderGhosttyAndNowhereElse() async throws {
    let zsh = "/bin/zsh"
    let files = try GeneratedIntegration(helper: "/bin/echo")
    defer { files.tearDown() }

    func output(termProgram: String?) async throws -> String {
      var environment = files.environment(termProgram: termProgram)
      environment["ZDOTDIR"] = files.zshDirectory.path
      return try await interactiveShellOutput(zsh, arguments: ["-i"], environment: environment)
    }

    let marked = try await output(termProgram: "ghostty")
    #expect(marked.contains(PromptMarks.claim))
    #expect(marked.contains(PromptMarks.input), "input start, or no cell is one a click can reach")
    #expect(
      marked.contains(PromptMarks.output),
      "output start too, or the claim would stand while a program ran")

    let plain = try await output(termProgram: nil)
    for mark in [PromptMarks.claim, PromptMarks.input, PromptMarks.output] {
      #expect(plain.contains(mark) == false, "a terminal that is not Ghostty is told nothing")
    }
  }

  /// readline drops the end of a screen-wide prompt, where the input mark rides. One machine's
  /// `/etc/bashrc` PS1 reached 80 columns and scrolled the mark off, so the test sets its own.
  @Test(.enabled(if: InstalledShells.isInstalled("/bin/bash")))
  func aRealBashWritesAllThreeMarksUnderGhosttyAndNoneWithoutIt() async throws {
    let bash = "/bin/bash"
    let files = try GeneratedIntegration(helper: "/bin/echo")
    defer { files.tearDown() }
    try files.writeHomeFile(".bashrc", "PS1='> '\n")

    func output(termProgram: String?) async throws -> String {
      var environment = files.environment(termProgram: termProgram)
      // The marks ride with the hooks, which do nothing outside a tab.
      environment[SessionEnvironment.sessionVariable] = "prompt-marks"
      return try await interactiveShellOutput(
        bash, arguments: ["--init-file", files.bashInit.path, "-i"], environment: environment)
    }

    let marked = try await output(termProgram: "ghostty")
    #expect(marked.contains(PromptMarks.claim), "prompt start")
    #expect(marked.contains("> " + PromptMarks.input), "input start, on the end of PS1")
    #expect(marked.contains(PromptMarks.output), "output start, once the command ran")

    let plain = try await output(termProgram: nil)
    for mark in [PromptMarks.claim, PromptMarks.input, PromptMarks.output] {
      #expect(plain.contains(mark) == false, "a terminal that is not Ghostty is told nothing")
    }
  }

  /// `%{` opens a zero-width span, so a PS1 ending in a bare `%` would take
  /// the mark's brace as a literal percent's and show the rest.
  @Test(.enabled(if: InstalledShells.isInstalled("/bin/zsh")))
  func aPromptEndingInAPercentKeepsItAndStillGetsTheInputMark() async throws {
    let zsh = "/bin/zsh"
    let files = try GeneratedIntegration(helper: "/bin/echo")
    defer { files.tearDown() }
    try files.writeHomeFile(".zshrc", "PS1='ready%'\n")
    var environment = files.environment(termProgram: "ghostty")
    environment["ZDOTDIR"] = files.zshDirectory.path

    let output = try await interactiveShellOutput(zsh, arguments: ["-i"], environment: environment)
    #expect(output.contains("ready%" + PromptMarks.input), "the percent shown, then the mark")
    #expect(output.contains("%{") == false, "and no brace leaks into the prompt")
  }

  /// Hooks run through `$SHELL -l -i -c`, which reads the rc files, so a mark written
  /// anywhere but a prompt hook would land in the output a hook is judged by.
  @Test(.enabled(if: InstalledShells.isInstalled("/bin/zsh")))
  func aShellRunningOneCommandWritesNoMarksIntoItsOutput() async throws {
    let zsh = "/bin/zsh"
    let files = try GeneratedIntegration(helper: "/bin/echo")
    defer { files.tearDown() }
    var environment = files.environment(termProgram: "ghostty")
    environment["ZDOTDIR"] = files.zshDirectory.path
    environment["GHOSTTY_SHELL_FEATURES"] = "cursor:blink,title"

    let output = try await interactiveShellOutput(
      zsh, arguments: ["-l", "-i", "-c", "cd /tmp; echo starting"], environment: environment,
      input: "")
    #expect(output.contains("starting"))
    #expect(output.contains("\u{1B}") == false, "no mark, title, cursor or directory report")
  }

  /// Our marks go back after a framework's entry rebuilds PS1, and the DEBUG trap arms
  /// last. bash 5.1 made `PROMPT_COMMAND` an array; an older one runs only element 0.
  @Test(.enabled(if: InstalledShells.isInstalled("/bin/bash")))
  func theUsersOwnPromptCommandEntriesKeepTheirPlaceBetweenOurs() async throws {
    let bash = "/bin/bash"
    let files = try GeneratedIntegration(helper: "/bin/echo")
    defer { files.tearDown() }
    try files.writeHomeFile(".bashrc", "PROMPT_COMMAND=(theirs_first theirs_second)\n")
    var environment = files.environment(termProgram: "ghostty")
    environment[SessionEnvironment.sessionVariable] = "prompt-command"

    let output = try await interactiveShellOutput(
      bash, arguments: ["--init-file", files.bashInit.path, "-i"], environment: environment,
      input: "declare -p PROMPT_COMMAND\nexit\n")
    let declared = try #require(output.range(of: "declare -a PROMPT_COMMAND=")).upperBound
    let listing = output[declared...]
    let order = [
      "_multishell_precmd", "theirs_first", "_multishell_prompt_marks", "_multishell_arm",
    ]
    let places = order.compactMap { listing.range(of: $0)?.lowerBound }
    #expect(places.count == order.count, "every entry is there")
    #expect(places == places.sorted(), "and in this order")
    #expect(listing.contains("theirs_second"))
  }

  @Test(.enabled(if: InstalledShells.isInstalled("/bin/bash")))
  func anArrayPromptCommandStillRunsOurHooksOnABashThatRunsOnlyItsFirstElement() async throws {
    let bash = "/bin/bash"
    let files = try GeneratedIntegration(helper: "/bin/echo")
    defer { files.tearDown() }
    try files.writeHomeFile(".bashrc", "PS1='> '\nPROMPT_COMMAND=(theirs_first theirs_second)\n")
    var environment = files.environment(termProgram: "ghostty")
    environment[SessionEnvironment.sessionVariable] = "array-prompt-command"

    let output = try await interactiveShellOutput(
      bash, arguments: ["--init-file", files.bashInit.path, "-i"], environment: environment,
      input: "true\nexit\n")
    #expect(output.contains(PromptMarks.claim))
    #expect(output.contains("> " + PromptMarks.input))
  }

  /// `zsh -i script` runs preexec for each line, and no prompt is ever shown.
  @Test func aScriptRunInAnInteractiveShellCarriesNoEscapes() async throws {
    let output = try await zshOutput(
      features: "cursor,title", input: "true\nprint -r done\n", runsInputAsScript: true)
    #expect(output.contains("done"))
    #expect(output.contains("\u{1B}") == false)
  }

  @Test func aRealZshTellsTheTerminalACommandEndedAndWithWhatStatus() async throws {
    let output = try await zshOutput(features: nil, input: "false\ntrue\nexit\n")
    #expect(output.contains(PromptMarks.commandEnd(1)))
    #expect(output.contains(PromptMarks.commandEnd(0)))
  }

  @Test func aPromptWithNoCommandBeforeItReportsNoEnd() async throws {
    let output = try await zshOutput(features: nil, input: "\nexit\n")
    #expect(output.contains(PromptMarks.input), "the hooks ran")
    #expect(output.contains(PromptMarks.anyCommandEnd) == false)
  }
}
