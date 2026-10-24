import Foundation
import TestScratch
import Testing

@testable import MultishellAppCore
@testable import MultishellCore

extension AppModelPersistenceTests {
  @Test func theFilesPanelsFilesOrGitIsOneChoiceKeptAcrossARelaunch() {
    let file = Scratch.statePath("files-panel-mode")
    defer { Scratch.remove(file.deletingLastPathComponent()) }
    let before = Harness(stateFile: file)

    before.model.setFilesPanelMode(.git)

    #expect(before.model.filesPanelState(of: before.feature.id).mode == .git)
    let (after, _, _, error) = before.relaunched()
    #expect(error == nil)
    #expect(after.filesPanelState(of: before.main.id).mode == .git)
  }

  @Test func modifiedOrBranchIsOneChoiceKeptAcrossARelaunch() {
    let file = Scratch.statePath("change-scope")
    defer { Scratch.remove(file.deletingLastPathComponent()) }
    let before = Harness(stateFile: file)

    before.model.setChangeScope(.branch)

    let (after, _, _, error) = before.relaunched()
    #expect(error == nil)
    #expect(after.workspace.changeScope == .branch)
  }
}
