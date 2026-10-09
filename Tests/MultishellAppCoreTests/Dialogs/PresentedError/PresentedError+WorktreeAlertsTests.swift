import Foundation
import Testing

@testable import MultishellAppCore
@testable import MultishellGitKit

@Suite
struct PresentedErrorWorktreeAlertsTests {
  /// The default arm prints a `LocalizedError` with `String(describing:)`, which gives the
  /// struct's fields rather than its sentence, so each one needs a case of its own.
  @Test func theGitKitErrorsReadAsSentencesRatherThanSwiftValues() {
    let branch = PresentedError(InvalidBranchName("my branch"))
    #expect(branch.message == "git will not take my branch as a branch name.")
    #expect(!branch.message.contains("InvalidBranchName"))
    #expect(!branch.title.isEmpty)

    let main = PresentedError(WorktreeNotRemovable(path: URL(fileURLWithPath: "/w/repo")))
    #expect(main.message.hasPrefix("/w/repo is the repository itself"))
    #expect(!main.message.contains("WorktreeNotRemovable"))
    #expect(!main.title.isEmpty)
  }

  @Test func aDirectoryThatIsNotTheWorktreeSaysItWasLeftAlone() {
    let presented = PresentedError(WorktreePathTaken(path: URL(fileURLWithPath: "/w/feature")))

    #expect(presented.title == "Worktree not removed: something else is at its path")
    #expect(presented.message.contains("/w/feature"))
    #expect(presented.message.contains("left it alone"))
  }

  @Test func aTrashThatTookNothingSaysSoInTheReadersLanguage() {
    let presented = PresentedError(
      TrashFailure(path: URL(fileURLWithPath: "/w/feature"), underlying: TrashTookNothing()))
    #expect(
      presented.title
        == "Worktree not removed: the directory could not be moved to the Trash or deleted")
    #expect(presented.message.contains("/w/feature"))
    #expect(presented.message.contains("The directory is still there."))
    #expect(!presented.message.contains("TrashTookNothing"))
  }
}
