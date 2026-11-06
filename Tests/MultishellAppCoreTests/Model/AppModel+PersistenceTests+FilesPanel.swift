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

    before.model.setFilesPanelMode(.changes)

    #expect(before.model.filesPanelState(of: before.feature.id).mode == .changes)
    let (after, _, _, error) = before.relaunched()
    #expect(error == nil)
    #expect(after.filesPanelState(of: before.main.id).mode == .changes)
  }

  @Test func anOpenFilesPanelIsStillOpenAfterARelaunch() {
    let file = Scratch.statePath("files-panel-open")
    defer { Scratch.remove(file.deletingLastPathComponent()) }
    let before = Harness(stateFile: file)
    before.model.select(before.feature)

    before.model.setShowsFilesPanel(true)

    let (after, _, _, error) = before.relaunched()
    #expect(error == nil)
    #expect(after.showsFilesPanel)
    after.select(before.feature)
    #expect(after.isFilesPanelOnScreen)
  }

  @Test func aFilesPanelShutBeforeARelaunchStaysShut() {
    let file = Scratch.statePath("files-panel-shut")
    defer { Scratch.remove(file.deletingLastPathComponent()) }
    let before = Harness(stateFile: file)
    before.model.setShowsFilesPanel(true)
    before.model.saveNow()

    before.model.setShowsFilesPanel(false)

    let (after, _, _, _) = before.relaunched()
    #expect(!after.showsFilesPanel)
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
