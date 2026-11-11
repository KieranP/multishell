import Testing

@testable import MultishellCore

@Suite
struct ShellWordsTests {
  @Test func quotedWordsStayWholeAndAnOpenQuoteTakesTheRest() {
    #expect(ShellWords.split(#"--a "b c" d\ e"#) == ["--a", "b c", "d e"])
    #expect(ShellWords.split("--a ''") == ["--a", ""], "an empty quoted word is an argument")
    #expect(ShellWords.split("--a 'b c") == ["--a", "b c"], "a quote left open takes the rest")
    #expect(
      ShellWords.split(#"--a "\#u{0301}b c" d"#) == ["--a", "\u{0301}b c", "d"],
      "a combining mark after a quote leaves the quote a quote",
    )
  }

  /// Checked case by case against zsh, and the whole rule against it by
  /// random lines over letters, spaces and the three quoting characters.
  @Test func aBackslashInsideDoubleQuotesGuardsOnlyTheFourTheShellGuards() {
    #expect(ShellWords.split(#""\d+""#) == [#"\d+"#], "a regex keeps its backslashes")
    #expect(ShellWords.split(##""\\""##) == [#"\"#], "two guard one")
    #expect(ShellWords.split(##""\"""##) == [#"""#], "and one guards the quote that would end it")
    #expect(ShellWords.split(##""\$""##) == ["$"])
    #expect(ShellWords.split(##""\`""##) == ["`"])
    #expect(ShellWords.split(#"\d"#) == ["d"], "outside quotes it guards everything")
    #expect(ShellWords.split(#"'\d'"#) == [#"\d"#], "inside single quotes it guards nothing")
  }

  @Test func anUnterminatedQuoteWithNothingInItPassesNothing() {
    #expect(ShellWords.split("--prompt \"") == ["--prompt"])
    #expect(ShellWords.split("--prompt '") == ["--prompt"])
    #expect(ShellWords.split("--prompt ''") == ["--prompt", ""], "closed, so it is an argument")
    #expect(ShellWords.split("--prompt 'b") == ["--prompt", "b"], "it did carry something")
  }

  /// An escape nothing completed used to end the line with an empty word,
  /// which reached the agent as an argument of its own.
  @Test func aTrailingBackslashPassesNothingRatherThanAnEmptyArgument() {
    #expect(ShellWords.split("--model opus \\") == ["--model", "opus"])
    #expect(ShellWords.split("\\") == [])
    #expect(ShellWords.split("\\a") == ["a"], "the word still starts on the escaped character")
  }

  @Test func aLinesProgramIsTheWordPastAssignmentsAndALauncherWithItsOptions() {
    #expect(ShellWords.program(of: "NVIM_APPNAME=lazy nvim {path}") == "nvim")
    #expect(ShellWords.program(of: #"FOO="a b" BAR=a\ b /opt/bin/hx x"#) == "/opt/bin/hx")
    #expect(ShellWords.program(of: "env -i FOO=1 nvim") == "nvim")
    #expect(ShellWords.program(of: "env -u FOO code .") == "code")
    #expect(ShellWords.program(of: "exec -a ed nvim") == "nvim")
    #expect(ShellWords.program(of: "command -p vim") == "vim")
    #expect(ShellWords.program(of: "FOO=1") == nil)
  }
}
