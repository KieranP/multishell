import Foundation
import Testing

@testable import MultishellAppCore
@testable import MultishellCore

@Suite
struct PresentedErrorUnreadableFileAlertsTests {
  @Test func aSettingsFileItWillNotRewriteSaysWhichAndWhatToDoInstead() {
    let file = URL(fileURLWithPath: "/Users/x/.gemini/settings.json")
    let unparsable = PresentedError(UnparsableSettingsFile(file: file))
    #expect(unparsable.title == "That settings file is not plain JSON")
    #expect(unparsable.message.contains("/Users/x/.gemini/settings.json"))
    #expect(unparsable.message.contains("comment"))
    #expect(unparsable.message.contains("Show JSON"))

    let entries = PresentedError(
      UnexpectedHookEntriesShape(file: file, section: "hooks", event: "BeforeTool")
    )
    #expect(entries.title == "That settings file has hooks Multishell does not recognise")
    #expect(entries.message.contains("hooks.BeforeTool"))
    #expect(entries.message.contains("Show JSON"))
    let namedSet = PresentedError(
      UnexpectedHookEntriesShape(file: file, section: "multishell", event: "Stop")
    )
    #expect(namedSet.message.contains("under multishell.Stop"))
    let section = PresentedError(UnexpectedHookSectionShape(file: file, section: "multishell"))
    #expect(section.message.contains("under multishell that"))

    let shape = PresentedError(UnexpectedSettingsShape(file: file))
    #expect(shape.title == "That settings file is not a JSON object")
    #expect(shape.message.contains("Show JSON"))
  }
}
