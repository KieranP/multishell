import Testing

@testable import MultishellAppCore

@Suite
struct NewWorktreeDraftTypedBranchTests {
  private func branchAfterTyping(_ text: String) -> String {
    var draft = NewWorktreeDraft(projectID: "/repos/a")
    draft.typeBranch(text)
    return draft.branch
  }

  @Test func aPastedControllerActionBecomesOneDashPerRunOfUnusualCharacters() {
    #expect(branchAfterTyping("Admin::UsersController#index") == "Admin-UsersController-index")
  }

  @Test func everyCharacterGitRefusesBecomesADash() {
    for refused in [" ", "~", "^", ":", "?", "*", "[", "\\", "\t", "\u{7f}"] {
      #expect(branchAfterTyping("a\(refused)b") == "a-b", "\(refused.debugDescription)")
    }
  }

  @Test func dashesBesideAReplacedCharacterJoinItsDash() {
    #expect(branchAfterTyping("fix - login") == "fix-login")
    #expect(branchAfterTyping("fix -- login") == "fix-login")
  }

  @Test func dashesTypedOnTheirOwnAreKept() {
    #expect(branchAfterTyping("fix--login") == "fix--login")
  }

  @Test func lettersDigitsAndTheSeparatorsGitTakesAreKept() {
    #expect(branchAfterTyping("feat/ünïcode_1.2-x") == "feat/ünïcode_1.2-x")
  }

  @Test func unusualCharactersLeadingTheNameAreDroppedRatherThanLeavingADash() {
    #expect(branchAfterTyping("#123 fix") == "123-fix")
    #expect(branchAfterTyping("  feat") == "feat")
  }

  @Test func trailingSpacesStayForTheTrimUntilAWordAfterThemDashesThem() {
    var draft = NewWorktreeDraft(projectID: "/repos/a")
    draft.typeBranch("feature/foo \t")
    #expect(draft.branch == "feature/foo \t")
    #expect(draft.trimmedBranch == "feature/foo")
    #expect(branchAfterTyping("feat x") == "feat-x")
  }

  @Test func aTrailingRunWithMoreThanSpacesStillBecomesADash() {
    #expect(branchAfterTyping("feat :") == "feat-")
    #expect(branchAfterTyping("feat\n") == "feat-")
  }

  @Test func charactersGitTakesButBranchesRarelyHaveBecomeDashesToo() {
    for unusual in ["#", "@", "+", ",", "'", "!", "🐛", "\n"] {
      #expect(branchAfterTyping("a\(unusual)b") == "a-b", "\(unusual.debugDescription)")
    }
  }

  @Test func anAccentTypedAsTwoScalarsIsKeptAsALetter() {
    #expect(branchAfterTyping("cafe\u{301}") == "cafe\u{301}")
  }

  @Test func nothingButUnusualCharactersLeavesTheFieldEmpty() {
    #expect(branchAfterTyping("") == "")
    #expect(branchAfterTyping("::") == "")
    #expect(branchAfterTyping("-#") == "")
  }

  @Test func aDashTypedFirstStaysForTheWarningToFlag() {
    var draft = NewWorktreeDraft(projectID: "/repos/a")
    draft.typeBranch("-x")
    #expect(draft.branch == "-x")
    #expect(draft.branchNameIsRefused)
  }

  @Test func namesBrokenOnlyInShapeAreLeftForTheWarning() {
    for shaped in ["a..b", "feat.", "feat.lock", ".hidden", "a//b"] {
      var draft = NewWorktreeDraft(projectID: "/repos/a")
      draft.typeBranch(shaped)
      #expect(draft.branch == shaped)
      #expect(draft.branchNameIsRefused, "\(shaped)")
    }
  }

  @Test func aFixedNameIsNotFlagged() {
    var draft = NewWorktreeDraft(projectID: "/repos/a")
    draft.typeBranch("Admin::UsersController#index")
    #expect(!draft.branchNameIsRefused)
  }

  @Test func fixingAFixedNameChangesNothing() {
    let inputs = [
      "Admin::UsersController#index", "fix - login", "#123 fix", "feature/foo \t", "feat :",
      "fix--login", "-x", "a..b", "  feat", "x 🐛 y",
    ]
    for input in inputs {
      let once = branchAfterTyping(input)
      #expect(branchAfterTyping(once) == once, "\(input.debugDescription)")
    }
  }

  @Test func theFixedNameComesBackAfterAVisitToTheExistingBranchPicker() {
    var draft = NewWorktreeDraft(projectID: "/repos/a")
    draft.typeBranch("Admin::Users")
    draft.createsBranch = false
    draft.fitBranchToMode(checkedOut: [])
    draft.createsBranch = true
    draft.fitBranchToMode(checkedOut: [])
    #expect(draft.branch == "Admin-Users")
  }
}
