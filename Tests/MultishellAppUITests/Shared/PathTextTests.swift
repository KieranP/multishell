import Foundation
import Testing

@testable import MultishellAppUI

@Suite @MainActor
struct PathTextTests {
  @Test func aPathUnderHomeIsShownWithATilde() {
    let home = FileManager.default.homeDirectoryForCurrentUser.path

    #expect(PathText(home + "/Library/state.json").path == "~/Library/state.json")
    #expect(PathText("/opt/state.json").path == "/opt/state.json")
  }
}
