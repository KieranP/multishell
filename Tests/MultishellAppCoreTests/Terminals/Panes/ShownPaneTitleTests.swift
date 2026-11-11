import Testing

@testable import MultishellAppCore
@testable import MultishellCore

@Suite
struct ShownPaneTitleTests {
  private let worktree = "/Users/me/Work/acme-worktrees/feat-auth"
  private let home = "/Users/me"

  private func shown(_ title: String) -> String {
    ShownPaneTitle.shown(title, worktreePath: worktree, home: home)
  }

  @Test func anAgentsStatusGlyphIsDroppedFromTheFront() {
    #expect(shown("✳ Request authentication") == "Request authentication")
    #expect(shown("⠋ Working on it") == "Working on it")
  }

  @Test func claudeCodesWorkingSpinnerIsDroppedInEveryFrame() {
    for frame in ["◐", "◑", "◒", "◓"] {
      #expect(shown("\(frame) App design review") == "App design review")
    }
  }

  @Test func geminisPaddedTitleLosesItsGlyphAndItsPadding() {
    let padded = "◇  Ready (feat-auth)" + String(repeating: " ", count: 60)
    #expect(shown(padded) == "Ready (feat-auth)")
  }

  @Test func aGlyphSentInItsEmojiFormIsDroppedToo() {
    #expect(shown("\u{270B}\u{FE0F}  Action Required") == "Action Required")
  }

  @Test func aGlyphWithNoSpaceAfterItIsPartOfTheTitle() {
    #expect(shown("✳Request") == "✳Request")
  }

  @Test func aTitleThatIsOnlyAGlyphIsKept() {
    #expect(shown("✳ ") == "✳")
  }

  @Test func aBlankTitleIsKeptAsItCame() {
    #expect(shown("   ") == "   ")
  }

  @Test func aShellAtTheWorktreesRootReadsAsAShell() {
    #expect(shown(worktree) == t("tab.shell"))
    #expect(shown("~/Work/acme-worktrees/feat-auth") == t("tab.shell"))
    #expect(shown("…/Work/acme-worktrees/feat-auth") == t("tab.shell"))
  }

  @Test func aShellBelowTheWorktreeNamesItsFolderFromTheRoot() {
    #expect(shown(worktree + "/src/routes") == "src/routes")
    #expect(shown("~/Work/acme-worktrees/feat-auth/src") == "src")
    #expect(shown("…/feat-auth/src/routes") == "src/routes")
  }

  @Test func aFolderStartingWithACombiningMarkIsNamedFromTheRootToo() {
    #expect(shown(worktree + "/\u{0301}sub") == "\u{0301}sub")
    #expect(shown("…/feat-auth/\u{0301}sub") == "\u{0301}sub")
  }

  @Test func aShellOutsideTheWorktreeKeepsItsTitle() {
    #expect(shown("~/Downloads") == "~/Downloads")
    #expect(
      shown("/Users/me/Work/acme-worktrees/feat-auth-old")
        == "/Users/me/Work/acme-worktrees/feat-auth-old"
    )
    #expect(shown("…/src/routes/api") == "…/src/routes/api")
  }

  @Test func aCommandTitleIsLeftAlone() {
    #expect(shown("npm test") == "npm test")
  }

  @Test func withNoWorktreePathOnlyTheStatusGlyphGoes() {
    #expect(
      ShownPaneTitle.shown("✳ /Users/me/x", worktreePath: nil, home: home) == "/Users/me/x"
    )
  }
}
