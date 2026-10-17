import MultishellCore
import Testing

@testable import MultishellAppCore

extension AppModelTabRenamingTests {
  @Test func aDoubleClickOnAFileTabOpensNoNameField() {
    let harness = Harness()
    let file = harness.openFileTab()

    harness.model.beginRenamingTab(file.id)

    #expect(harness.model.renamingTabID == nil)
  }
}
