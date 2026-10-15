import TestScratch
import Testing

@testable import MultishellCore

/// The pane's title, the directory at a prompt and the command while it runs.
extension ShellIntegrationScriptsTests {
  @Test func aRealZshTitlesThePaneWithItsDirectoryAndThenTheCommand() async throws {
    let output = try await zshOutput(features: "title", input: "cd\necho hi\nexit\n")
    #expect(
      output.contains(TerminalReports.title("~")),
      "the directory at a prompt, home as a tilde",
    )
    #expect(output.contains(TerminalReports.title("echo hi")), "the command while it runs")
  }

  @Test func aDeepDirectoryIsTitledByItsLastThreeParts() async throws {
    let input = "mkdir -p ~/a/b/c/d/e && cd ~/a/b/c/d/e\nexit\n"
    let output = try await zshOutput(features: "title", input: input)
    #expect(output.contains(TerminalReports.title("…/c/d/e")))
  }

  @Test func aTitleIsLeftAloneWhenTheUsersFeaturesLeaveItOut() async throws {
    let output = try await zshOutput(features: "cursor", input: "true\nexit\n")
    #expect(output.contains(TerminalReports.cursorShape(5)), "the features that are on still ran")
    #expect(output.contains(TerminalReports.anyTitle) == false)
  }

  /// Its directory reports alone made libghostty title the pane with the raw path.
  @Test(arguments: InstalledBashes.all)
  func aRealBashTitlesThePaneWithItsDirectory(bash: String) async throws {
    let output = try await bashOutput(bash, features: "title", input: "cd\nexit\n", usersRC: "")
    #expect(output.contains(TerminalReports.title("~")), "\(output)")
  }

  @Test(arguments: InstalledBashes.all)
  func aDeepBashDirectoryIsTitledByItsLastThreeParts(bash: String) async throws {
    let input = "mkdir -p ~/a/b/c/d/e && cd ~/a/b/c/d/e\nexit\n"
    let output = try await bashOutput(bash, features: "title", input: input, usersRC: "")
    #expect(output.contains(TerminalReports.title("…/c/d/e")), "\(output)")
  }

  @Test(arguments: InstalledBashes.all)
  func aBashTitleIsLeftAloneWhenTheUsersFeaturesLeaveItOut(bash: String) async throws {
    let output = try await bashOutput(bash, features: "cursor", input: "true\nexit\n", usersRC: "")
    #expect(output.contains(TerminalReports.anyTitle) == false)
  }

  /// The directory goes as unknown, which leaves libghostty's title as it was.
  @Test(arguments: InstalledBashes.all)
  func aBashDirectoryWithAControlCharacterIsTitledWithoutIt(bash: String) async throws {
    let tabbed = "\"$HOME/x\"$'\\t'\"y\""
    let input = "mkdir -p \(tabbed) && cd \(tabbed)\nexit\n"
    let output = try await bashOutput(bash, features: "title", input: input, usersRC: "")
    #expect(output.contains(TerminalReports.title("~/xy")), "\(output)")
  }

  @Test(arguments: InstalledBashes.all)
  func aBashTitleShowsNoTildeWhereHomeIsEmpty(bash: String) async throws {
    let input = "HOME=; cd /usr/bin\nexit\n"
    let output = try await bashOutput(bash, features: "title", input: input, usersRC: "")
    #expect(output.contains(TerminalReports.title("/usr/bin")), "\(output)")
  }
}
