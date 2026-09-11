import Foundation
import TestScratch
import Testing

@testable import MultishellCore

/// The OSC 133 marks a prompt writes about itself, which are what let a click
/// inside it move the cursor. zsh only has to add the claim to the marks
/// Ghostty's own integration already writes; bash has to write all of them,
/// since Ghostty writes none for it.
@Suite
struct PromptMarkTests {
  @Test func theZshPromptSaysAClickInItMayMoveTheCursor() {
    let zshrc = ShellStateHooks.zshIntegrationFiles(helper: "/x/multishell")[".zshrc"] ?? ""
    #expect(zshrc.contains("]133;A;cl=line"))
    #expect(
      zshrc.contains("]133;B"), "and the input mark, so the claim never stands over unmarked text")
    #expect(zshrc.contains("add-zsh-hook precmd _multishell_prompt_click"), "on every prompt")
    #expect(
      zshrc.contains("add-zsh-hook preexec _multishell_prompt_output"),
      "and output start, so the claim does not stand while a program runs")
    #expect(
      zshrc.contains("[ \"${TERM_PROGRAM-}\" = ghostty ]"),
      "a SwiftTerm tab has no other marks, so a lone one would open a prompt it never ends")
  }

  @Test func theBashPromptCarriesEveryMarkItself() {
    let text = ShellStateHooks.bashInitFile(helper: "/x/multishell")
    #expect(text.contains("]133;A;cl=line"), "prompt start, and the claim")
    #expect(text.contains("]133;B"), "input start, or no cell is one a click can reach")
    #expect(
      text.contains("]133;C"),
      "output start, or a click would answer with arrows while a program runs")
    #expect(text.contains("133;D") == false, "the exit code is the socket's to report, not both")
    #expect(
      text.range(of: "_multishell_prompt_marks; _multishell_arm") != nil,
      "put back last, after a framework has rebuilt PS1 from a PROMPT_COMMAND of its own")
  }

  /// The claims are only worth something if a real shell writes them at a
  /// prompt. The generated files are a chain, and a hook that fell out of it
  /// anywhere would leave every one of them valid shell.
  @Test func aRealZshWritesTheClaimAtItsPromptUnderGhosttyAndNowhereElse() throws {
    let zsh = "/bin/zsh"
    guard FileManager.default.isExecutableFile(atPath: zsh) else { return }
    let files = try GeneratedIntegration(helper: "/bin/echo")
    defer { files.remove() }

    func output(termProgram: String?) throws -> String {
      var environment = files.environment(termProgram: termProgram)
      environment["ZDOTDIR"] = files.zshDirectory.path
      return try interactiveShell(zsh, arguments: ["-i"], environment: environment)
    }

    let marked = try output(termProgram: "ghostty")
    #expect(marked.contains(Marks.claim))
    #expect(marked.contains(Marks.input), "input start, or no cell is one a click can reach")
    #expect(
      marked.contains(Marks.output),
      "output start too, or the claim would stand while a program ran")

    let plain = try output(termProgram: nil)
    for mark in [Marks.claim, Marks.input, Marks.output] {
      #expect(plain.contains(mark) == false, "a terminal that is not Ghostty is told nothing")
    }
  }

  /// A prompt of its own, because the input mark rides on the end of PS1 and
  /// readline drops the end of a prompt as wide as the screen: on a machine
  /// whose `/etc/bashrc` made `\h:\W \u\$` reach 80 columns, the mark was
  /// written and then scrolled off, and the test read as our file's fault.
  @Test func aRealBashWritesAllThreeMarksUnderGhosttyAndNoneWithoutIt() throws {
    let bash = "/bin/bash"
    guard FileManager.default.isExecutableFile(atPath: bash) else { return }
    let files = try GeneratedIntegration(helper: "/bin/echo")
    defer { files.remove() }
    try files.writeHomeFile(".bashrc", "PS1='> '\n")

    func output(termProgram: String?) throws -> String {
      var environment = files.environment(termProgram: termProgram)
      // The marks ride with the hooks, which do nothing outside a tab.
      environment[SessionEnvironment.sessionKey] = "prompt-marks"
      return try interactiveShell(
        bash, arguments: ["--init-file", files.bashInit.path, "-i"], environment: environment)
    }

    let marked = try output(termProgram: "ghostty")
    #expect(marked.contains(Marks.claim), "prompt start")
    #expect(marked.contains("> " + Marks.input), "input start, on the end of PS1")
    #expect(marked.contains(Marks.output), "output start, once the command ran")

    let plain = try output(termProgram: nil)
    for mark in [Marks.claim, Marks.input, Marks.output] {
      #expect(plain.contains(mark) == false, "a terminal that is not Ghostty is told nothing")
    }
  }

  /// `%{` opens a zero-width span, so a PS1 ending in a bare `%` would take
  /// the mark's brace as a literal percent's and show the rest.
  @Test func aPromptEndingInAPercentKeepsItAndStillGetsTheInputMark() throws {
    let zsh = "/bin/zsh"
    guard FileManager.default.isExecutableFile(atPath: zsh) else { return }
    let files = try GeneratedIntegration(helper: "/bin/echo")
    defer { files.remove() }
    try files.writeHomeFile(".zshrc", "PS1='ready%'\n")
    var environment = files.environment(termProgram: "ghostty")
    environment["ZDOTDIR"] = files.zshDirectory.path

    let output = try interactiveShell(zsh, arguments: ["-i"], environment: environment)
    #expect(output.contains("ready%" + Marks.input), "the percent shown, then the mark")
    #expect(output.contains("%{") == false, "and no brace leaks into the prompt")
  }

  /// A mark belongs at a prompt, never in what a command wrote. Hooks run
  /// through `$SHELL -l -i -c`, which reads the rc files, so a mark written
  /// anywhere but a prompt hook would land in the output a hook is judged by.
  @Test func aShellRunningOneCommandWritesNoMarksIntoItsOutput() throws {
    let zsh = "/bin/zsh"
    guard FileManager.default.isExecutableFile(atPath: zsh) else { return }
    let files = try GeneratedIntegration(helper: "/bin/echo")
    defer { files.remove() }
    var environment = files.environment(termProgram: "ghostty")
    environment["ZDOTDIR"] = files.zshDirectory.path

    let output = try interactiveShell(
      zsh, arguments: ["-l", "-i", "-c", "echo starting"], environment: environment, input: "")
    #expect(output.contains("starting"))
    #expect(output.contains("\u{1B}]133;") == false, "nothing a hook's message would carry")
  }

  /// Where our entries sit in `PROMPT_COMMAND` is the whole of the bash
  /// design: the marks have to be put back after a framework's own entry has
  /// rebuilt PS1, and arming the DEBUG trap has to come after everything.
  /// bash 5.1 made `PROMPT_COMMAND` an array, so both shapes are built.
  @Test func theUsersOwnPromptCommandEntriesKeepTheirPlaceBetweenOurs() throws {
    let bash = "/bin/bash"
    guard FileManager.default.isExecutableFile(atPath: bash) else { return }
    let files = try GeneratedIntegration(helper: "/bin/echo")
    defer { files.remove() }
    try files.writeHomeFile(".bashrc", "PROMPT_COMMAND=(theirs_first theirs_second)\n")
    var environment = files.environment(termProgram: "ghostty")
    environment[SessionEnvironment.sessionKey] = "prompt-command"

    let output = try interactiveShell(
      bash, arguments: ["--init-file", files.bashInit.path, "-i"], environment: environment,
      input: "declare -p PROMPT_COMMAND\nexit\n")
    let order =
      ["_multishell_precmd", "theirs_first", "theirs_second"]
      + ["_multishell_prompt_marks", "_multishell_arm"]
    let places = order.compactMap { output.range(of: $0, options: .backwards)?.lowerBound }
    #expect(places.count == order.count, "every entry is there")
    #expect(places == places.sorted(), "and in this order")
  }

  /// `TERM_PROGRAM` is the one variable these files read that a terminal may
  /// genuinely not set, and a shell run with `nounset` treats reading it as an
  /// error: zsh writes one at every startup, and bash abandons the rest of the
  /// init file, taking the command-status hooks with it.
  @Test func aShellRunWithNounsetIsNotTrippedByTheTerminalItIsNotIn() throws {
    let files = try GeneratedIntegration(helper: "/bin/echo")
    defer { files.remove() }
    var environment = files.environment(termProgram: nil)

    if FileManager.default.isExecutableFile(atPath: "/bin/zsh") {
      try files.writeHomeFile(".zshrc", "setopt nounset\n")
      environment["ZDOTDIR"] = files.zshDirectory.path
      let output = try interactiveShell("/bin/zsh", arguments: ["-i"], environment: environment)
      #expect(output.contains("parameter not set") == false, "no error at every startup")
      environment["ZDOTDIR"] = nil
    }

    guard FileManager.default.isExecutableFile(atPath: "/bin/bash") else { return }
    try files.writeHomeFile(".bashrc", "set -u\n")
    environment[SessionEnvironment.sessionKey] = "nounset"
    let output = try interactiveShell(
      "/bin/bash", arguments: ["--init-file", files.bashInit.path, "-i"],
      environment: environment,
      // Printed by the hooks' own name, so the echoed line cannot stand in
      // for the answer.
      input: "declare -F _multishell_precmd >/dev/null && printf 'HOOKS%s\\n' OK\nexit\n")
    #expect(output.contains("unbound variable") == false, "nothing to abandon the file for")
    #expect(output.contains("HOOKSOK"), "the hooks outlive the rest of the file")
  }

  /// libghostty's zsh integration is reached only through its own bootstrap
  /// `.zshenv`, which restores the `ZDOTDIR` it displaced and chains on to it.
  /// The engine applies a surface's variables after setting that up, so the
  /// session has to name the pair itself. Stood in for by a bootstrap that
  /// keeps the same contract: enter the displaced directory, and from a
  /// deferred precmd write a plain prompt start and the input mark.
  @Test func aFreshTabEntersTheEnginesBootstrapWhichChainsOnToOurs() throws {
    let zsh = "/bin/zsh"
    guard FileManager.default.isExecutableFile(atPath: zsh) else { return }
    let files = try GeneratedIntegration(helper: "/bin/echo")
    defer { files.remove() }
    let bootstrap = try files.writeEngineBootstrap()
    var environment = files.environment(termProgram: "ghostty")
    environment.merge(
      SessionEnvironment.zshIntegration(
        shellPath: zsh, environment: [:], integrationDirectory: files.zshDirectory,
        engineBootstrap: bootstrap)
    ) { _, new in new }
    #expect(environment["ZDOTDIR"] == bootstrap.path)

    let output = try interactiveShell(zsh, arguments: ["-i"], environment: environment)
    #expect(output.contains(Marks.input), "the engine's mark, so the chain reached its file")
    #expect(output.contains(Marks.claim), "and ours, so the chain came on to our file")
    let plain = try #require(output.range(of: Marks.plainStart, options: .backwards))
    let claim = try #require(output.range(of: Marks.claim, options: .backwards))
    #expect(plain.lowerBound < claim.lowerBound, "the claim still lands last")
  }

  /// The shell that replaces an exited agent is started by a fragment, not
  /// by the session's environment, so it names the same pair itself, found
  /// through the variable the engine leaves in every child.
  @Test func theShellAfterAnAgentEntersTheEnginesBootstrapUnderGhosttyOnly() throws {
    let zsh = "/bin/zsh"
    guard FileManager.default.isExecutableFile(atPath: zsh) else { return }
    let files = try GeneratedIntegration(helper: "/bin/echo")
    defer { files.remove() }
    _ = try files.writeEngineBootstrap()
    // A tab is a pty, so the shell it starts is interactive; a pipe is not.
    let exec = ShellLaunch.execCommandLine(
      forShell: zsh, zshIntegration: files.zshDirectory, bashInit: files.bashInit
    ).replacingOccurrences(of: "exec \(zsh) -l", with: "exec \(zsh) -l -i")
    #expect(exec.contains(files.engineResources.path) == false, "found at run time, not baked in")

    var ghostty = files.environment(termProgram: "ghostty")
    ghostty["GHOSTTY_RESOURCES_DIR"] = files.engineResources.path
    let chained = try interactiveShell(
      "/bin/sh", arguments: ["-c", "true; \(exec)"], environment: ghostty)
    #expect(chained.contains(Marks.plainStart), "the engine's file was entered")
    #expect(chained.contains(Marks.claim), "and ours after it")

    // The login shell running the line may not be POSIX; csh is the one at hand.
    if FileManager.default.isExecutableFile(atPath: "/bin/csh") {
      let fromCsh = try interactiveShell(
        "/bin/csh", arguments: ["-c", "true; \(exec)"], environment: ghostty)
      #expect(fromCsh.contains(Marks.plainStart), "the fragment reads the same to csh")
      #expect(fromCsh.contains(Marks.claim))
    }

    var elsewhere = files.environment(termProgram: nil)
    elsewhere[SessionEnvironment.sessionKey] = "after-agent"
    elsewhere[SessionEnvironment.socketKey] = "/nonexistent.sock"
    let plain = try interactiveShell(
      "/bin/sh", arguments: ["-c", "true; \(exec)"], environment: elsewhere,
      input: "(( $+functions[_multishell_precmd] )) && printf 'HOOKS%s\\n' OK\nexit\n")
    #expect(plain.contains(Marks.plainStart) == false, "no engine, no bootstrap")
    #expect(plain.contains(Marks.claim) == false, "and no claim outside Ghostty")
    #expect(plain.contains("HOOKSOK"), "but ours was entered directly")
  }

  private enum Marks {
    static let claim = "\u{1B}]133;A;cl=line\u{7}"
    static let plainStart = "\u{1B}]133;A\u{7}"
    static let input = "\u{1B}]133;B\u{7}"
    static let output = "\u{1B}]133;C\u{7}"
  }
}

/// The integration files as the app writes them, in a directory of their own,
/// beside a home holding no startup file, so a shell run against them reads
/// nothing this machine has.
private struct GeneratedIntegration {
  let root: URL
  let home: URL
  let zshDirectory: URL
  let bashInit: URL

  init(helper: String) throws {
    root = Scratch.path("marks")
    home = root.appendingPathComponent("home", isDirectory: true)
    zshDirectory = root.appendingPathComponent("zsh", isDirectory: true)
    bashInit = root.appendingPathComponent("bash/init.bash")
    try FileManager.default.createDirectory(at: home, withIntermediateDirectories: true)
    try ShellIntegration.refresh(zshDirectory: zshDirectory, bashInit: bashInit, helper: helper)
  }

  func remove() {
    try? FileManager.default.removeItem(at: root)
  }

  /// Where a stand-in for the engine's resources goes; the bootstrap is at
  /// `shell-integration/zsh` below it, as libghostty's is.
  var engineResources: URL { root.appendingPathComponent("resources", isDirectory: true) }

  /// A bootstrap with libghostty's contract: restore the `ZDOTDIR` it
  /// displaced from `GHOSTTY_ZSH_ZDOTDIR`, source that directory's `.zshenv`,
  /// and from a precmd deferred past `.zshrc` write a plain prompt start and
  /// put the input mark on the end of PS1.
  func writeEngineBootstrap() throws -> URL {
    let dir = engineResources.appendingPathComponent("shell-integration/zsh", isDirectory: true)
    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    let contents = """
      if [[ -n "${GHOSTTY_ZSH_ZDOTDIR+set}" ]]; then
        ZDOTDIR="$GHOSTTY_ZSH_ZDOTDIR"; unset GHOSTTY_ZSH_ZDOTDIR
      else
        unset ZDOTDIR
      fi
      [[ -r "${ZDOTDIR:-$HOME}/.zshenv" ]] && builtin source -- "${ZDOTDIR:-$HOME}/.zshenv"
      if [[ -o interactive ]]; then
        _engine_precmd() {
          print -n -- $'\\e]133;A\\a'
          [[ "$PS1" == *$'\\e]133;B\\a%}' ]] || PS1="$PS1"$'%{\\e]133;B\\a%}'
        }
        _engine_defer() {
          precmd_functions=(${precmd_functions:#_engine_defer})
          autoload -Uz add-zsh-hook
          add-zsh-hook precmd _engine_precmd
          _engine_precmd
        }
        typeset -ga precmd_functions
        precmd_functions+=(_engine_defer)
      fi

      """
    try Data(contents.utf8).write(to: dir.appendingPathComponent(".zshenv"), options: .atomic)
    return dir
  }

  /// A startup file for the shell to chain to, as a user's own would be.
  func writeHomeFile(_ name: String, _ contents: String) throws {
    try Data(contents.utf8).write(to: home.appendingPathComponent(name), options: .atomic)
  }

  func environment(termProgram: String?) -> [String: String] {
    var environment = ["HOME": home.path, "PATH": "/usr/bin:/bin", "TERM": "dumb"]
    environment["TERM_PROGRAM"] = termProgram
    return environment
  }
}

/// Everything one interactive shell writes before `exit` reaches it, its
/// prompt included: bash writes its prompt to stderr and zsh to stdout, so
/// the two are read as one.
private func interactiveShell(
  _ executable: String, arguments: [String], environment: [String: String],
  input: String = "true\nexit\n"
) throws -> String {
  let process = Process()
  process.executableURL = URL(fileURLWithPath: executable)
  process.arguments = arguments
  process.environment = environment
  let stdin = Pipe()
  let output = Pipe()
  process.standardInput = stdin
  process.standardOutput = output
  process.standardError = output
  try process.run()
  stdin.fileHandleForWriting.write(Data(input.utf8))
  try? stdin.fileHandleForWriting.close()
  let text = String(decoding: output.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
  process.waitUntilExit()
  return text
}
