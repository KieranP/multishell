import Foundation
import TestScratch
import Testing

@testable import MultishellAppCore
@testable import MultishellCore

extension AppModelPersistenceTests {
  @Test func theFilesPanelsAllOrModifiedIsOneChoiceKeptAcrossARelaunch() {
    let file = Scratch.statePath("files-panel-mode")
    defer { Scratch.remove(file.deletingLastPathComponent()) }
    let before = Harness(stateFile: file)

    before.model.setFilesPanelMode(.modified)

    #expect(before.model.filesPanelState(of: before.feature.id).mode == .modified)
    let (after, _, _, error) = before.relaunched()
    #expect(error == nil)
    #expect(after.filesPanelState(of: before.main.id).mode == .modified)
  }
}
