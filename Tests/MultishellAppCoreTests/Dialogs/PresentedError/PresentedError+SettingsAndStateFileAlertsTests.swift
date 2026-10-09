import Foundation
import Testing

@testable import MultishellAppCore
@testable import MultishellCore

@Suite
struct PresentedErrorSettingsAndStateFileAlertsTests {
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

  @Test func aSettingsFileItWillNotRewriteSaysWhichAndWhatToDoInstead() {
    let file = URL(fileURLWithPath: "/Users/x/.gemini/settings.json")
    let unparsable = PresentedError(UnparsableSettingsFile(file: file))
    #expect(unparsable.title == "That settings file is not plain JSON")
    #expect(unparsable.message.contains("/Users/x/.gemini/settings.json"))
    #expect(unparsable.message.contains("comment"))
    #expect(unparsable.message.contains("Show JSON"))

    let entries = PresentedError(UnexpectedHookEntriesShape(file: file, event: "BeforeTool"))
    #expect(entries.title == "That settings file has hooks Multishell does not recognise")
    #expect(entries.message.contains("hooks.BeforeTool"))
    #expect(entries.message.contains("Show JSON"))

    let shape = PresentedError(UnexpectedSettingsShape(file: file))
    #expect(shape.title == "That settings file is not a JSON object")
    #expect(shape.message.contains("Show JSON"))
  }
}
