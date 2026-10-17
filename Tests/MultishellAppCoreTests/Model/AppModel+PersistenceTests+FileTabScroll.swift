import Foundation
import TestScratch
import Testing

@testable import MultishellAppCore
@testable import MultishellCore

extension AppModelPersistenceTests {
  @Test func aFileTabsScrollIsBackAfterARelaunch() throws {
    let file = Scratch.statePath("file-tab-scroll")
    defer { Scratch.remove(file.deletingLastPathComponent()) }
    let before = Harness(stateFile: file)
    let tab = try #require(before.store.openFileTab(path: "README.md", in: before.main.id))
    before.model.noteFileTabScrolled(
      tab.id,
      to: FileTabScroll(line: 0, isHEADsLine: false, rowsFromLine: 240.5, x: 12),
    )

    let (after, _, _, error) = before.relaunched()

    #expect(error == nil)
    #expect(
      after.fileTabScroll(of: tab.id)
        == FileTabScroll(line: 0, isHEADsLine: false, rowsFromLine: 240.5, x: 12)
    )
  }
}
