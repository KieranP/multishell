import Testing

@testable import MultishellCore

/// The cursor's shape: a bar to type in, a block in vi command mode, and the
/// user's own shape while a program runs.
extension ShellIntegrationScriptsTests {
  @Test func theCursorIsABarAtThePromptAndTheUsersShapeWhileACommandRuns() async throws {
    let blinking = try await zshOutput(features: "cursor:blink", input: "true\nexit\n")
    #expect(blinking.contains(TerminalReports.cursorShape(5)), "a blinking bar to edit in")
    #expect(
      blinking.contains(TerminalReports.cursorShape(0)),
      "the configured shape back for the program",
    )

    let steady = try await zshOutput(features: "cursor:steady", input: "true\nexit\n")
    #expect(steady.contains(TerminalReports.cursorShape(6)))

    let none = try await zshOutput(features: "title", input: "true\nexit\n")
    #expect(none.contains(TerminalReports.anyTitle), "the features that are on still ran")
    #expect(none.contains(TerminalReports.cursorShape(5)) == false)
    #expect(none.contains(TerminalReports.cursorShape(0)) == false)
  }

  @Test func viCommandModeShowsABlockAndInsertModeABar() async throws {
    let input = """
      KEYMAP=vicmd _multishell_keymap_cursor; print -n '|'; KEYMAP=viins _multishell_keymap_cursor; print -n '|'
      exit

      """
    let blinking = try await zshOutput(features: "cursor:blink", input: input)
    #expect(
      blinking.contains(TerminalReports.cursorShape(1) + "|" + TerminalReports.cursorShape(5) + "|")
    )

    let steady = try await zshOutput(features: "cursor:steady", input: input)
    #expect(
      steady.contains(TerminalReports.cursorShape(2) + "|" + TerminalReports.cursorShape(6) + "|")
    )

    let none = try await zshOutput(features: "title", input: input)
    #expect(none.contains("||"), "no shape at all where the user turned the cursor off")
  }

  @Test func theCursorFollowsEveryKeymapChangeNotOnlyEachPrompt() async throws {
    let output = try await zleOutput(
      features: "cursor",
      after: "zstyle -L zle-keymap-select; zstyle -L zle-line-init",
    )
    #expect(output.contains("zle-keymap-select widgets 1:_multishell_keymap_cursor"))
    #expect(output.contains("zle-line-init widgets 1:_multishell_keymap_cursor"))
  }

  /// oh-my-zsh's vi-mode and prezto draw their own shapes from this hook,
  /// and ours ran after theirs, so theirs was overdrawn on every change.
  @Test func aCursorWidgetOfTheUsersOwnKeepsTheCursor() async throws {
    let call = "KEYMAP=vicmd _multishell_keymap_cursor; print -n '|'"
    let alone = try await zleOutput(features: "cursor:blink", after: call)
    #expect(
      alone.hasSuffix(TerminalReports.cursorShape(1) + "|"),
      "ours draws where no widget of theirs is set",
    )

    let theirs = "theirs() { print -n theirs }; zle -N zle-keymap-select theirs"
    let beside = try await zleOutput(features: "cursor:blink", after: call, before: theirs)
    #expect(beside.hasSuffix("|"))
    #expect(beside.contains(TerminalReports.cursorShape(1)) == false)
  }

  @Test func aUsersKshArraysStillLeavesACursorWidgetAddedAfterOursAlone() async throws {
    let theirs = "theirs() { print -n theirs }; add-zle-hook-widget keymap-select theirs"
    let output = try await zleOutput(
      features: "cursor:blink",
      after: "\(theirs); KEYMAP=vicmd _multishell_keymap_cursor; print -n '|'",
      before: "setopt ksh_arrays",
    )
    #expect(output.hasSuffix("|"))
    #expect(output.contains(TerminalReports.cursorShape(1)) == false)
  }

  @Test func aUsersErrReturnStillGetsTheKeymapCursor() async throws {
    let output = try await zleOutput(
      features: "cursor:blink",
      after: "zstyle -L zle-keymap-select",
      before: "setopt err_return",
    )
    #expect(output.contains("_multishell_keymap_cursor"))
  }
}
