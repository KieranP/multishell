import Foundation
import Testing

@testable import MultishellCore

/// What the generated files have to survive: the user's own startup files,
/// which they source before adding anything of their own.
extension ShellIntegrationScriptsTests {
  @Test func aRealBashKeepsWhatTheUsersOwnStartupFilesSetUp() async throws {
    let bash = "/bin/bash"
    guard FileManager.default.isExecutableFile(atPath: bash) else { return }
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

      """)
    try files.writeHomeFile(".bash_profile", "[ -f ~/.bashrc ] && . ~/.bashrc\n")

    var environment = files.environment(termProgram: "ghostty")
    environment[SessionEnvironment.sessionVariable] = "user-files"
    let output = try await interactiveShellOutput(
      bash, arguments: ["--init-file", files.bashInit.path, "-i"], environment: environment,
      input:
        "echo \"COUNT=$(printf %s \"$MARKER_PATH\" | tr ':' '\\n' | grep -c '^/opt/marker$')\"\nexit\n"
    )

    #expect(output.contains("syntax error") == false, "a PROMPT_COMMAND ending in `;` made `;;`")
    #expect(output.contains("[theirs]"), "their DEBUG trap still fires, chained ahead of ours")
    #expect(output.contains("COUNT=1"), ".bashrc was sourced twice, so PATH gained it twice")
    #expect(output.contains(PromptMarks.claim), "and our own hooks still reach the prompt")
  }

  /// A terminal may leave `TERM_PROGRAM` unset. Under `nounset`, reading it makes zsh
  /// print an error at every startup and bash abandon the init file, hooks and all.
  @Test func aShellRunWithNounsetIsNotTrippedByTheTerminalItIsNotIn() async throws {
    let files = try GeneratedIntegration(helper: "/bin/echo")
    defer { files.tearDown() }
    var environment = files.environment(termProgram: nil)

    if FileManager.default.isExecutableFile(atPath: "/bin/zsh") {
      try files.writeHomeFile(".zshrc", "setopt nounset\n")
      environment["ZDOTDIR"] = files.zshDirectory.path
      let output = try await interactiveShellOutput(
        "/bin/zsh", arguments: ["-i"], environment: environment)
      #expect(output.contains("parameter not set") == false, "no error at every startup")
      environment["ZDOTDIR"] = nil
    }

    guard FileManager.default.isExecutableFile(atPath: "/bin/bash") else { return }
    try files.writeHomeFile(".bashrc", "set -u\n")
    environment[SessionEnvironment.sessionVariable] = "nounset"
    let output = try await interactiveShellOutput(
      "/bin/bash", arguments: ["--init-file", files.bashInit.path, "-i"],
      environment: environment,
      // Printed by the hooks' own name, so the echoed line cannot stand in
      // for the answer.
      input: "declare -F _multishell_precmd >/dev/null && printf 'HOOKS%s\\n' OK\nexit\n")
    #expect(output.contains("unbound variable") == false, "nothing to abandon the file for")
    #expect(output.contains("HOOKSOK"), "the hooks outlive the rest of the file")
  }
}
