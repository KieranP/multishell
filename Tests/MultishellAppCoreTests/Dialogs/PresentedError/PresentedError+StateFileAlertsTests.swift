import Foundation
import Testing

@testable import MultishellAppCore
@testable import MultishellCore

@Suite
struct PresentedErrorStateFileAlertsTests {
  @Test func unreadableStateNamesTheBackupFile() {
    let backup = URL(fileURLWithPath: "/tmp/state.2026.broken.json")
    let presented = PresentedError(
      UnreadableStateFile(backup: backup, underlying: CocoaError(.coderReadCorrupt))
    )
    #expect(presented.title == "Saved state could not be read")
    #expect(presented.message.contains("state.2026.broken.json"))
  }

  @Test func unmovedStateNamesTheFileStillStandingThere() {
    let file = URL(fileURLWithPath: "/tmp/state.json")
    let presented = PresentedError(
      UnmovableStateFile(fileURL: file, underlying: CocoaError(.coderReadCorrupt))
    )
    #expect(presented.title == "Saved state could not be read")
    #expect(presented.message.contains("/tmp/state.json"))
    #expect(presented.message.contains("Nothing will be saved over it"))
  }

  @Test func aLinkTargetGoneMidSessionSaysSavingStopsUntilItIsBack() {
    let presented = PresentedError(
      GoneStateFileLinkTarget(
        fileURL: URL(fileURLWithPath: "/tmp/state.json"),
        target: URL(fileURLWithPath: "/dotfiles/state.json"),
      )
    )
    #expect(presented.title == "State is not being saved")
    #expect(presented.message.contains("/dotfiles/state.json"))
    #expect(!presented.message.contains("started empty"))
  }
}
