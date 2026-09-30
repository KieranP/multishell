import Foundation
import Testing

@testable import MultishellCore

/// OSC 133 marks let a click in a prompt move the cursor. zsh adds the claim to
/// Ghostty's own marks, and bash writes all of them, since Ghostty writes none for it.
extension ShellStateHooksTests {
  @Test func theZshPromptSaysAClickInItMayMoveTheCursor() {
    let zshrc = ShellStateHooks.zshIntegrationScripts(helper: "/x/multishell")[".zshrc"] ?? ""
    #expect(zshrc.contains("]133;A;cl=line"))
    #expect(
      zshrc.contains("]133;B"), "and the input mark, so the claim never stands over unmarked text")
    #expect(zshrc.contains("add-zsh-hook precmd _multishell_prompt_click"), "on every prompt")
    #expect(
      zshrc.contains("add-zsh-hook preexec _multishell_prompt_output"),
      "and output start, so the claim does not stand while a program runs")
    #expect(
      zshrc.contains("[ \"${TERM_PROGRAM-}\" = ghostty ]"),
      "elsewhere there are no other marks, so a lone one would open a prompt it never ends")
  }

  @Test func theBashPromptCarriesEveryMarkItself() {
    let text = ShellStateHooks.bashInitScript(helper: "/x/multishell")
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
  @Test func aRealZshWritesTheClaimAtItsPromptUnderGhosttyAndNowhereElse() async throws {
    let zsh = "/bin/zsh"
    guard FileManager.default.isExecutableFile(atPath: zsh) else { return }
    let files = try GeneratedIntegration(helper: "/bin/echo")
    defer { files.tearDown() }

    func output(termProgram: String?) async throws -> String {
      var environment = files.environment(termProgram: termProgram)
      environment["ZDOTDIR"] = files.zshDirectory.path
      return try await interactiveShell(zsh, arguments: ["-i"], environment: environment)
    }

    let marked = try await output(termProgram: "ghostty")
    #expect(marked.contains(Marks.claim))
    #expect(marked.contains(Marks.input), "input start, or no cell is one a click can reach")
    #expect(
      marked.contains(Marks.output),
      "output start too, or the claim would stand while a program ran")

    let plain = try await output(termProgram: nil)
    for mark in [Marks.claim, Marks.input, Marks.output] {
      #expect(plain.contains(mark) == false, "a terminal that is not Ghostty is told nothing")
    }
  }

  /// readline drops the end of a screen-wide prompt, where the input mark rides. One machine's
  /// `/etc/bashrc` PS1 reached 80 columns and scrolled the mark off, so the test sets its own.
  @Test func aRealBashWritesAllThreeMarksUnderGhosttyAndNoneWithoutIt() async throws {
    let bash = "/bin/bash"
    guard FileManager.default.isExecutableFile(atPath: bash) else { return }
    let files = try GeneratedIntegration(helper: "/bin/echo")
    defer { files.tearDown() }
    try files.writeHomeFile(".bashrc", "PS1='> '\n")

    func output(termProgram: String?) async throws -> String {
      var environment = files.environment(termProgram: termProgram)
      // The marks ride with the hooks, which do nothing outside a tab.
      environment[SessionEnvironment.sessionKey] = "prompt-marks"
      return try await interactiveShell(
        bash, arguments: ["--init-file", files.bashInit.path, "-i"], environment: environment)
    }

    let marked = try await output(termProgram: "ghostty")
    #expect(marked.contains(Marks.claim), "prompt start")
    #expect(marked.contains("> " + Marks.input), "input start, on the end of PS1")
    #expect(marked.contains(Marks.output), "output start, once the command ran")

    let plain = try await output(termProgram: nil)
    for mark in [Marks.claim, Marks.input, Marks.output] {
      #expect(plain.contains(mark) == false, "a terminal that is not Ghostty is told nothing")
    }
  }

  /// `%{` opens a zero-width span, so a PS1 ending in a bare `%` would take
  /// the mark's brace as a literal percent's and show the rest.
  @Test func aPromptEndingInAPercentKeepsItAndStillGetsTheInputMark() async throws {
    let zsh = "/bin/zsh"
    guard FileManager.default.isExecutableFile(atPath: zsh) else { return }
    let files = try GeneratedIntegration(helper: "/bin/echo")
    defer { files.tearDown() }
    try files.writeHomeFile(".zshrc", "PS1='ready%'\n")
    var environment = files.environment(termProgram: "ghostty")
    environment["ZDOTDIR"] = files.zshDirectory.path

    let output = try await interactiveShell(zsh, arguments: ["-i"], environment: environment)
    #expect(output.contains("ready%" + Marks.input), "the percent shown, then the mark")
    #expect(output.contains("%{") == false, "and no brace leaks into the prompt")
  }

  /// Hooks run through `$SHELL -l -i -c`, which reads the rc files, so a mark written
  /// anywhere but a prompt hook would land in the output a hook is judged by.
  @Test func aShellRunningOneCommandWritesNoMarksIntoItsOutput() async throws {
    let zsh = "/bin/zsh"
    guard FileManager.default.isExecutableFile(atPath: zsh) else { return }
    let files = try GeneratedIntegration(helper: "/bin/echo")
    defer { files.tearDown() }
    var environment = files.environment(termProgram: "ghostty")
    environment["ZDOTDIR"] = files.zshDirectory.path

    let output = try await interactiveShell(
      zsh, arguments: ["-l", "-i", "-c", "echo starting"], environment: environment, input: "")
    #expect(output.contains("starting"))
    #expect(output.contains("\u{1B}]133;") == false, "nothing a hook's message would carry")
  }

  /// Our marks go back after a framework's entry rebuilds PS1, and the DEBUG trap arms
  /// last. bash 5.1 made `PROMPT_COMMAND` an array; an older one runs only element 0.
  @Test func theUsersOwnPromptCommandEntriesKeepTheirPlaceBetweenOurs() async throws {
    let bash = "/bin/bash"
    guard FileManager.default.isExecutableFile(atPath: bash) else { return }
    let files = try GeneratedIntegration(helper: "/bin/echo")
    defer { files.tearDown() }
    try files.writeHomeFile(".bashrc", "PROMPT_COMMAND=(theirs_first theirs_second)\n")
    var environment = files.environment(termProgram: "ghostty")
    environment[SessionEnvironment.sessionKey] = "prompt-command"

    let output = try await interactiveShell(
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

  @Test func anArrayPromptCommandStillRunsOurHooksOnABashThatRunsOnlyItsFirstElement() async throws
  {
    let bash = "/bin/bash"
    guard FileManager.default.isExecutableFile(atPath: bash) else { return }
    let files = try GeneratedIntegration(helper: "/bin/echo")
    defer { files.tearDown() }
    try files.writeHomeFile(".bashrc", "PS1='> '\nPROMPT_COMMAND=(theirs_first theirs_second)\n")
    var environment = files.environment(termProgram: "ghostty")
    environment[SessionEnvironment.sessionKey] = "array-prompt-command"

    let output = try await interactiveShell(
      bash, arguments: ["--init-file", files.bashInit.path, "-i"], environment: environment,
      input: "true\nexit\n")
    #expect(output.contains(Marks.claim))
    #expect(output.contains("> " + Marks.input))
  }

  enum Marks {
    static let claim = "\u{1B}]133;A;cl=line\u{7}"
    static let plainStart = "\u{1B}]133;A\u{7}"
    static let input = "\u{1B}]133;B\u{7}"
    static let output = "\u{1B}]133;C\u{7}"
  }
}
