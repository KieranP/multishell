import Foundation
import TestScratch
import Testing

@testable import MultishellCore

/// What the generated files have to survive: the user's own startup files,
/// which they source before adding anything of their own.
extension ShellIntegrationScriptsTests {
  /// A tab's bash stands for a login shell but is not one, so it refused
  /// `logout` and ran no `~/.bash_logout`.
  @Test(arguments: InstalledBashes.all)
  func aTabsBashLogsOutAsALoginShellWould(bash: String) async throws {
    let files = try GeneratedIntegration(helper: "/bin/echo")
    defer { files.tearDown() }
    try files.writeHomeFile(".bashrc", "PS1='> '\n")
    try files.writeHomeFile(".bash_logout", "echo LOGGED-OUT-$((1+1))\n")

    let output = try await interactiveShellOutput(
      bash,
      arguments: ["--init-file", files.bashInit.path, "-i"],
      environment: files.environment(termProgram: nil),
      input: "logout\n",
    )

    #expect(!output.contains("not login shell"), "\(output)")
    #expect(output.contains("LOGGED-OUT-2"), "\(output)")
  }

  /// A login shell runs `~/.bash_logout` on `exit`, `logout` or end of input,
  /// never on a hangup, which every pane close and quit sends.
  @Test(arguments: InstalledBashes.all)
  func aTabsBashHungUpRunsNoLogoutFile(bash: String) async throws {
    let files = try GeneratedIntegration(helper: "/bin/echo")
    defer { files.tearDown() }
    try files.writeHomeFile(".bashrc", "PS1='> '\n")
    try files.writeHomeFile(".bash_logout", "echo LOGGED-OUT-$((1+1))\n")

    let output = try await interactiveShellOutput(
      bash,
      arguments: ["--init-file", files.bashInit.path, "-i"],
      environment: files.environment(termProgram: nil),
      input: "kill -HUP $$\n",
    )

    #expect(!output.contains("LOGGED-OUT-2"), "\(output)")
  }

  @Test(.enabled(if: InstalledShells.isInstalled("/bin/bash")))
  func aRealBashKeepsWhatTheUsersOwnStartupFilesSetUp() async throws {
    let bash = "/bin/bash"
    let files = try GeneratedIntegration(helper: "/bin/echo")
    defer { files.tearDown() }
    // A trailing `;` composed to `;;`, which bash refuses, and a bare
    // `trap ... DEBUG` replaced theirs: Atuin and bash-preexec go silent.
    try files.writeHomeFile(
      ".bashrc",
      """
      PS1='> '
      MARKER_PATH="/opt/marker:$MARKER_PATH"
      theirs() { echo "[theirs]"; }
      trap 'theirs' DEBUG
      PROMPT_COMMAND='history -a;'

      """,
    )
    try files.writeHomeFile(".bash_profile", "[ -f ~/.bashrc ] && . ~/.bashrc\n")

    var environment = files.environment(termProgram: "ghostty")
    environment[SessionEnvironment.sessionVariable] = "user-files"
    let output = try await interactiveShellOutput(
      bash,
      arguments: ["--init-file", files.bashInit.path, "-i"],
      environment: environment,
      input:
        "echo \"COUNT=$(printf %s \"$MARKER_PATH\" | tr ':' '\\n' | grep -c '^/opt/marker$')\"\nexit\n",
    )

    #expect(output.contains("syntax error") == false, "a PROMPT_COMMAND ending in `;` made `;;`")
    #expect(output.contains("[theirs]"), "their DEBUG trap still fires, chained ahead of ours")
    #expect(output.contains("COUNT=1"), ".bashrc was sourced twice, so PATH gained it twice")
    #expect(output.contains(PromptMarks.claim), "and our own hooks still reach the prompt")
  }

  @Test(.enabled(if: InstalledShells.isInstalled("/bin/bash")))
  func aBashStartedInsideAPaneInheritsNoneOfOurPromptHooks() async throws {
    let files = try GeneratedIntegration(helper: "/bin/echo")
    defer { files.tearDown() }
    try files.writeHomeFile(".bashrc", "export PROMPT_COMMAND='history -a'\n")
    var environment = files.environment(termProgram: "ghostty")
    environment[SessionEnvironment.sessionVariable] = "exported-prompt-command"

    let output = try await interactiveShellOutput(
      "/bin/bash",
      arguments: ["--init-file", files.bashInit.path, "-i"],
      environment: environment,
      input: "/bin/bash -c 'printf \"CHILD[%s]\\\\n\" \"${PROMPT_COMMAND-}\"'\nexit\n",
    )

    #expect(output.contains("CHILD["), "the child printed nothing: \(output)")
    #expect(
      !output.contains("CHILD[_multishell"),
      "a child bash runs hooks it has no functions for",
    )
  }

  /// A terminal may leave `TERM_PROGRAM` unset. Under `nounset`, reading it makes zsh
  /// print an error at every startup and bash abandon the init file, hooks and all.
  @Test(.enabled(if: InstalledShells.isInstalled("/bin/bash")))
  func aShellRunWithNounsetIsNotTrippedByTheTerminalItIsNotIn() async throws {
    let files = try GeneratedIntegration(helper: "/bin/echo")
    defer { files.tearDown() }
    var environment = files.environment(termProgram: nil)

    if InstalledShells.isInstalled("/bin/zsh") {
      try files.writeHomeFile(".zshrc", "setopt nounset\n")
      let output = try await interactiveShellOutput(
        "/bin/zsh",
        arguments: ["-i"],
        environment: files.zshEnvironment(termProgram: nil),
      )
      #expect(output.contains("parameter not set") == false, "no error at every startup")
    }

    try files.writeHomeFile(".bashrc", "set -u\n")
    environment[SessionEnvironment.sessionVariable] = "nounset"
    let output = try await interactiveShellOutput(
      "/bin/bash",
      arguments: ["--init-file", files.bashInit.path, "-i"],
      environment: environment,
      // Printed by the hooks' own name, so the echoed line cannot stand in
      // for the answer.
      input: "declare -F _multishell_precmd >/dev/null && printf 'HOOKS%s\\n' OK\nexit\n",
    )
    #expect(output.contains("unbound variable") == false, "nothing to abandon the file for")
    #expect(output.contains("HOOKSOK"), "the hooks outlive the rest of the file")
  }

  /// Only a login shell reads ~/.zprofile.
  @Test(.enabled(if: InstalledShells.isInstalled("/bin/zsh")))
  func zshIntegrationFollowsAZdotdirSetByTheUsersZprofile() async throws {
    let files = try GeneratedIntegration(helper: "/bin/echo")
    defer { files.tearDown() }
    let relocated = files.home.appendingPathComponent(".config/zsh", isDirectory: true)
    try FileManager.default.createDirectory(at: relocated, withIntermediateDirectories: true)
    try files.writeHomeFile(".zprofile", "export ZDOTDIR=\"$HOME/.config/zsh\"\n")
    try files.writeHomeFile(".config/zsh/.zshrc", "export MULTISHELL_USER_RC_LOADED=relocated\n")

    let output = try await Detached.output(
      of: "/bin/zsh",
      ["-l", "-i", "-c", "printf '%s|%s' \"$MULTISHELL_USER_RC_LOADED\" \"$ZDOTDIR\""],
      environment: files.zshEnvironment(termProgram: nil),
      in: files.home,
      standardError: .discarded,
    )

    let fields = output.split(separator: "|", omittingEmptySubsequences: false)
    #expect(fields.first == "relocated", "the relocated .zshrc did not run: \(output)")
    #expect(
      fields.count == 2 && fields[1] == relocated.path,
      "ZDOTDIR handed back to the relocated dir: \(output)",
    )
  }
}
