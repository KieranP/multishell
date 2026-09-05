import Foundation
import MultishellCore
import MultishellGitKit
import MultishellProcess
import Testing

@testable import Multishell

/// The alert is the one place a user learns why something failed, so each
/// error type must come out with a title that names the situation and a
/// message that carries git's own words.
@Suite
struct PresentedErrorTests {
  @Test func gitFailuresShowStderrAsTheMessage() {
    let failure = ProcessFailure(
      executable: "git", arguments: ["worktree", "add", "-b", "x"], status: 128,
      message: "fatal: a branch named 'x' already exists")
    let presented = PresentedError(failure)
    #expect(presented.title == "git worktree add failed")
    #expect(presented.message == "fatal: a branch named 'x' already exists")
  }

  @Test func anEmptyStderrFallsBackToTheExitStatus() {
    let presented = PresentedError(
      ProcessFailure(executable: "git", arguments: ["status"], status: 3, message: ""))
    #expect(presented.message == "Exit status 3.")
  }

  @Test func anUnbornHEADIsExplainedInPlainWords() {
    let failure = ProcessFailure(
      executable: "git", arguments: ["worktree", "add"], status: 128,
      message: "fatal: invalid reference: HEAD")
    let presented = PresentedError(failure)
    #expect(presented.title == "This repository has no commits yet")
    #expect(presented.message.contains("first commit"))
  }

  @Test func hookFailuresSayTheWorktreeStillExists() {
    let failure = HookFailure(
      stage: .postCreate,
      underlying: ProcessFailure(
        executable: "sh", arguments: ["-c", "npm install"], status: 1, message: "npm ERR!"))
    let presented = PresentedError(failure)
    #expect(presented.title == "Worktree created, but its hook failed")
    #expect(presented.message == "npm ERR!")
  }

  @Test func preHookFailuresSayTheOperationDidNotHappen() {
    let refused = ProcessFailure(
      executable: "zsh", arguments: ["-l", "-i", "-c", "exit 1"], status: 1,
      message: "no ticket number")
    let create = PresentedError(HookFailure(stage: .preCreate, underlying: refused))
    #expect(create.title == "Worktree not created: its pre-create hook failed")
    #expect(create.message == "no ticket number")
    let delete = PresentedError(HookFailure(stage: .preDelete, underlying: refused))
    #expect(delete.title == "Worktree not removed: its pre-delete hook failed")
    #expect(
      PresentedError(HookFailure(stage: .postDelete, underlying: refused)).title
        == "Worktree removed, but its hook failed")
  }

  @Test func unreadableStateNamesTheBackupFile() {
    let backup = URL(fileURLWithPath: "/tmp/state.2026.broken.json")
    let presented = PresentedError(
      UnreadableState(backup: backup, underlying: CocoaError(.coderReadCorrupt)))
    #expect(presented.title == "Saved state could not be read")
    #expect(presented.message.contains("state.2026.broken.json"))
  }

  @Test func retryIsAbsentUnlessAdded() {
    var presented = PresentedError(GitUnavailable())
    #expect(presented.retryLabel == nil && presented.retry == nil)
    presented.retryLabel = "Remove Anyway"
    #expect(presented.retryLabel == "Remove Anyway")
  }
}

@Suite
struct UIMetricsTests {
  @Test func everySizeGrowsWithTheBase() {
    let small = UIMetrics(fontSize: 11)
    let large = UIMetrics(fontSize: 16)
    for keyPath in [
      \UIMetrics.body, \.secondary, \.caption, \.badge, \.mono, \.icon, \.rowHeight, \.tabHeight,
      \.indent,
    ] {
      #expect(small[keyPath: keyPath] < large[keyPath: keyPath])
    }
  }

  @Test func rowsAreTallEnoughForTheirText() {
    for size in stride(from: 10.0, through: 18.0, by: 1) {
      let metrics = UIMetrics(fontSize: size)
      #expect(metrics.rowHeight >= metrics.body * 1.8, "size \(size)")
      #expect(metrics.badge >= 7, "badge text must stay legible at \(size)")
    }
  }
}

@Suite
struct ThemeColourTests {
  @Test func chromeLiftsTowardsTheOppositeOfTheBackground() {
    let dark = Theme.multishellDark
    let light = Theme.multishellLight
    let lifted = dark.backgroundRGB.blended(with: .white, amount: 0.09)
    #expect(lifted.red > dark.backgroundRGB.red)
    let sunk = light.backgroundRGB.blended(with: .black, amount: 0.09)
    #expect(sunk.red < light.backgroundRGB.red)
  }

  @Test func blendingClampsAndRounds() {
    let rgb = RGB(red: 10, green: 20, blue: 30)
    #expect(rgb.blended(with: .white, amount: 2) == .white)
    #expect(rgb.blended(with: .white, amount: -1) == rgb)
    #expect(
      rgb.blended(with: RGB(red: 20, green: 20, blue: 20), amount: 0.5)
        == RGB(red: 15, green: 20, blue: 25))
  }
}
