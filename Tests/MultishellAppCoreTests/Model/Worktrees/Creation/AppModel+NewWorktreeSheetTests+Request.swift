import Foundation
import MultishellCore
import Testing

@testable import MultishellAppCore

extension AppModelNewWorktreeSheetTests {
  @Test func theMenuWithOneProjectAndNothingSelectedPicksThatProject() {
    let harness = Harness()
    harness.model.requestNewWorktree()
    #expect(harness.model.newWorktreeRequest?.projectID == harness.project.id)
  }

  @Test func theMenuWithSeveralProjectsAndNothingSelectedOpensWithNoProject() {
    let harness = Harness()
    harness.store.addProject(at: URL(fileURLWithPath: "/other"))

    harness.model.requestNewWorktree()

    #expect(harness.model.newWorktreeRequest != nil, "used to do nothing, silently")
    #expect(harness.model.newWorktreeRequest?.projectID == nil, "the picker starts blank")
  }

  @Test func theMenuOverTheBoardWithSeveralProjectsOpensWithNoProject() {
    let harness = Harness()
    harness.store.addProject(at: URL(fileURLWithPath: "/other"))
    harness.model.select(harness.feature)
    harness.model.showAgentBoard()

    harness.model.requestNewWorktree()

    #expect(
      harness.model.newWorktreeRequest?.projectID == nil,
      "nothing on screen names a project",
    )
  }

  @Test func theMenuFollowsTheSelectedWorktreesProject() {
    let harness = Harness()
    let other = harness.store.addProject(at: URL(fileURLWithPath: "/other"))
    harness.model.select(harness.feature)

    harness.model.requestNewWorktree()

    #expect(harness.model.newWorktreeRequest?.projectID == harness.project.id)
    #expect(harness.model.newWorktreeRequest?.projectID != other.id)
  }

  @Test func theSidebarNamesItsProjectWhateverIsSelected() {
    let harness = Harness()
    let other = harness.store.addProject(at: URL(fileURLWithPath: "/other"))
    harness.model.select(harness.main)

    harness.model.requestNewWorktree(in: other)

    #expect(harness.model.newWorktreeRequest?.projectID == other.id)
  }

  @Test func eachRequestIsANewPresentation() {
    let harness = Harness()
    harness.model.requestNewWorktree()
    let first = harness.model.newWorktreeRequest?.id
    harness.model.newWorktreeRequest = nil
    harness.model.requestNewWorktree()
    #expect(harness.model.newWorktreeRequest?.id != first, "the sheet must reopen after a cancel")
  }
}
